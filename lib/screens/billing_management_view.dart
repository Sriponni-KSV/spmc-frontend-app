import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  List<Map<String, dynamic>> _catalogServices = [];
  List<PatientModel> _patients = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _ipAdmissions = [];
  bool _isLoadingCatalog = false;
  bool _isLoadingPatients = false;
  bool _isLoadingInvoices = false;
  bool _isLoadingAdmissions = false;

  // Search queries
  String _catalogSearch = '';
  String _invoiceSearch = '';
  String _ipSearch = '';
  String _homeCareStatusFilter = 'All';

  // For Pharmacy Billing
  String? _selectedPharmacyMedId;
  String? _pharmacyMedName;
  bool _isCustomPharmacyItem = false;
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
      int tabLength = 5;
      if (role == 'Pharmacy') {
        tabLength = 3;
      } else if (role == 'Lab') {
        tabLength = 3;
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
    super.dispose();
  }

  void _loadAllData() {
    _loadCatalog();
    _loadPatients();
    _loadInvoices();
    _loadIpAdmissions();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.role == 'Pharmacy') {
      _loadMedicineInventory();
    }
  }

  void _refreshDataForTab(int tabIndex) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final role = user?.role;

    if (role == 'Pharmacy') {
      if (tabIndex == 0) {
        _loadMedicineInventory();
        _loadPatients();
      } else if (tabIndex == 1) {
        _loadInvoices();
      } else if (tabIndex == 2) {
        _loadCatalog();
      }
    } else if (role == 'Lab') {
      if (tabIndex == 0) {
        _loadCatalog();
        _loadPatients();
      } else if (tabIndex == 1) {
        _loadInvoices();
      } else if (tabIndex == 2) {
        _loadCatalog();
      }
    } else {
      if (tabIndex == 0) {
        _loadCatalog();
        _loadPatients();
      } else if (tabIndex == 1) {
        _loadInvoices();
      } else if (tabIndex == 2) {
        _loadIpAdmissions();
      } else if (tabIndex == 3) {
        _loadInvoices();
      } else if (tabIndex == 4) {
        _loadCatalog();
      }
    }
  }

  Future<void> _loadMedicineInventory() async {
    try {
      final response = await ApiService.get('${dotenv.env['BASE_URL']}/inventory/items');
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
        } else if (role == 'Receptionist' || role == 'Front Desk' || role == 'Reception') {
          filteredList = list.where((s) => s['category'] != 'Lab' && s['category'] != 'Pharmacy').toList();
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
    setState(() => _isLoadingPatients = true);
    try {
      final list = await _patientCtrl.fetchPatients();
      if (mounted) setState(() => _patients = list);
    } catch (e) {
      debugPrint('Error loading patients: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPatients = false);
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
      subtitle = 'Manage pharmacy bills, prescriptions, drug dispensing invoices, and payments';
      tabs = const [
        Tab(icon: Icon(Icons.receipt_outlined), text: 'Quick Bill (Pharmacy)'),
        Tab(icon: Icon(Icons.history_outlined), text: 'Pharmacy Invoices'),
        Tab(icon: Icon(Icons.medication_outlined), text: 'Medication Prices'),
      ];
      tabViews = [
        _buildQuickBillTab(isMobile),
        _buildInvoicesTab(isMobile),
        _buildCatalogTab(isMobile),
      ];
    } else if (role == 'Lab') {
      subtitle = 'Manage lab test requests billing, patient invoices, and service prices';
      tabs = const [
        Tab(icon: Icon(Icons.receipt_outlined), text: 'Quick Bill (Lab)'),
        Tab(icon: Icon(Icons.history_outlined), text: 'Lab Invoices'),
        Tab(icon: Icon(Icons.biotech_outlined), text: 'Lab Tests Catalog'),
      ];
      tabViews = [
        _buildQuickBillTab(isMobile),
        _buildInvoicesTab(isMobile),
        _buildCatalogTab(isMobile),
      ];
    } else {
      tabs = const [
        Tab(icon: Icon(Icons.receipt_outlined), text: 'Quick Bill (OP)'),
        Tab(icon: Icon(Icons.history_outlined), text: 'OP Invoices'),
        Tab(icon: Icon(Icons.hotel_outlined), text: 'IP Billing'),
        Tab(icon: Icon(Icons.home_work_outlined), text: 'Home Care'),
        Tab(icon: Icon(Icons.settings_outlined), text: 'Services Catalog'),
      ];
      tabViews = [
        _buildQuickBillTab(isMobile),
        _buildInvoicesTab(isMobile),
        _buildIpBillingTab(isMobile),
        _buildHomeCareBillingTab(isMobile),
        _buildCatalogTab(isMobile),
      ];
    }

    return Scaffold(
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
                  style: TextStyle(
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
              isScrollable: isMobile,
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
                  const Text('Quick Bill Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                  const SizedBox(height: 20),
                  
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
                        setState(() {
                          _qbSelectedPatient = _patients.firstWhere((p) => p.id.toString() == val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Item Selector
                  if (role == 'Pharmacy') ...[
                    Row(
                      children: [
                        Checkbox(
                          value: _isCustomPharmacyItem,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (val) {
                            setState(() {
                              _isCustomPharmacyItem = val ?? false;
                              _selectedPharmacyMedId = null;
                              _pharmacyMedName = null;
                              _customPharmacyItemCtrl.clear();
                            });
                          },
                        ),
                        const Text(
                          'Custom/Non-Inventory Item',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildLabel(_isCustomPharmacyItem ? 'Item Name *' : 'Medicine *'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _isCustomPharmacyItem
                              ? TextFormField(
                                  controller: _customPharmacyItemCtrl,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Item Name',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    fillColor: const Color(0xFFF1F5F9),
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  ),
                                )
                              : CustomDropdownSearch(
                                  label: '',
                                  hint: 'Select Medicine',
                                  value: _selectedPharmacyMedId,
                                  dropdownMap: {
                                    for (var med in _medicineInventory)
                                      med['id'].toString(): '${med['name']} (${med['quantity']} in stock)'
                                  },
                                  onChanged: (val) {
                                    if (val != null) {
                                      final medObj = _medicineInventory.firstWhere((x) => x['id'].toString() == val);
                                      setState(() {
                                        _selectedPharmacyMedId = val;
                                        _pharmacyMedName = medObj['name'];
                                      });
                                    }
                                  },
                                ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: _pharmacyPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              hintText: 'Price',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              fillColor: const Color(0xFFF1F5F9),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextFormField(
                            controller: _pharmacyQtyCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              hintText: 'Qty',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              fillColor: const Color(0xFFF1F5F9),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor, size: 36),
                          onPressed: () {
                            final String name = _isCustomPharmacyItem ? _customPharmacyItemCtrl.text.trim() : (_pharmacyMedName ?? '');
                            if (name.isEmpty || _pharmacyPriceCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select/enter item name and price'), backgroundColor: Colors.red));
                              return;
                            }
                            final double pr = double.tryParse(_pharmacyPriceCtrl.text) ?? 0.0;
                            final int qt = int.tryParse(_pharmacyQtyCtrl.text) ?? 1;
                            
                            setState(() {
                              final idx = _qbSelectedItems.indexWhere((x) => x['item_name'] == name);
                              if (idx >= 0) {
                                _qbSelectedItems[idx]['quantity'] = (_qbSelectedItems[idx]['quantity'] as int) + qt;
                              } else {
                                _qbSelectedItems.add({
                                  'service_id': null,
                                  'item_name': name,
                                  'quantity': qt,
                                  'unit_price': pr,
                                });
                              }
                              _selectedPharmacyMedId = null;
                              _pharmacyMedName = null;
                              _customPharmacyItemCtrl.clear();
                              _pharmacyPriceCtrl.clear();
                              _pharmacyQtyCtrl.text = '1';
                            });
                          },
                        )
                      ],
                    ),
                  ] else ...[
                    _buildLabel('Add Service to Bill'),
                    Row(
                      children: [
                        Expanded(
                          child: CustomDropdownSearch(
                            label: '',
                            hint: 'Choose Service',
                            dropdownMap: {
                              for (var s in _catalogServices.where((x) => x['category'] != 'IP'))
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
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bill Items Table Card
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
                  const Text('Selected Bill Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                  const SizedBox(height: 16),
                  if (_qbSelectedItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(child: Text('No items added. Select a service above.', style: TextStyle(color: Colors.grey.shade500))),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _qbSelectedItems.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _qbSelectedItems[index];
                        final qty = item['quantity'] as int;
                        final price = item['unit_price'] as double;
                        final total = qty * price;

                        return Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        if (qty > 1) {
                                          item['quantity'] = qty - 1;
                                        } else {
                                          _qbSelectedItems.removeAt(index);
                                        }
                                      });
                                    },
                                  ),
                                  Text('$qty'),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        item['quantity'] = qty + 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('₹${price.toStringAsFixed(2)}', textAlign: TextAlign.right),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('₹${total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _qbSelectedItems.removeAt(index);
                                });
                              },
                            )
                          ],
                        );
                      },
                    ),
                  
                  if (_qbSelectedItems.isNotEmpty) ...[
                    const Divider(height: 32, thickness: 1.2),
                    _buildSummaryRow('Subtotal', subtotal),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                    Row(
                      children: ['Cash', 'Card', 'UPI', 'Insurance'].map((mode) {
                        final selected = _qbPaymentMode == mode;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(mode),
                            selected: selected,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            backgroundColor: Colors.grey.shade100,
                            onSelected: (val) {
                              if (val) setState(() => _qbPaymentMode = mode);
                            },
                          ),
                        );
                      }).toList(),
                    ),
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
                        const SizedBox(width: 16),
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
    final idx = _qbSelectedItems.indexWhere((x) => x['service_id'] == service['id']);
    if (idx >= 0) {
      setState(() {
        _qbSelectedItems[idx]['quantity'] = (_qbSelectedItems[idx]['quantity'] as int) + 1;
      });
    } else {
      setState(() {
        _qbSelectedItems.add({
          'service_id': service['id'],
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
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final role = user?.role;
    final type = role == 'Pharmacy' ? 'Pharmacy' : (role == 'Lab' ? 'Lab' : 'OP');

    try {
      final res = await _billingCtrl.createInvoice(
        patientId: _qbSelectedPatient!.id!,
        admissionType: type,
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
          _qbSelectedItems = [];
          _qbDiscount = 0.0;
          _qbDiscountController.text = '0';
          _qbPaidController.text = '0';
          _qbRefController.text = '';
        });
        _loadInvoices();
        _showInvoiceReceiptDialog(res['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildInvoicesTab(bool isMobile) {
    final user = Provider.of<AuthProvider>(context).user;
    final role = user?.role;

    final filtered = _invoices.where((inv) {
      if (role == 'Pharmacy') {
        if (inv['admission_type'] != 'Pharmacy') return false;
      } else if (role == 'Lab') {
        if (inv['admission_type'] != 'Lab') return false;
      } else if (role == 'Receptionist' || role == 'Front Desk' || role == 'Reception') {
        if (inv['admission_type'] == 'Lab' || inv['admission_type'] == 'Pharmacy') return false;
        if (inv['admission_type'] != 'OP') return false;
      } else {
        if (inv['admission_type'] != 'OP') return false;
      }
      final q = _invoiceSearch.toLowerCase();
      return (inv['invoice_number'] ?? '').toString().toLowerCase().contains(q) ||
             (inv['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
             (inv['patient_display_id'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  onChanged: (val) => setState(() => _invoiceSearch = val),
                  decoration: const InputDecoration(
                    hintText: 'Search by Invoice Number, Patient Name, or ID...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _loadInvoices,
              )
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingInvoices
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(child: Text('No OP invoices found.', style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final inv = filtered[index];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.borderColor),
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Text(inv['invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  const SizedBox(width: 12),
                                  _buildPaymentStatusBadge(inv['payment_status']),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Patient: ${inv['patient_name']} (${inv['patient_display_id']})\n'
                                  'Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(inv['created_at']).toLocal())}',
                                  style: const TextStyle(height: 1.3),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${double.parse(inv['net_amount'].toString()).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Paid: ₹${double.parse(inv['paid_amount'].toString()).toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                              onTap: () => _showInvoiceReceiptDialog(inv['id']),
                            ),
                          );
                        },
                      ),
          ),
        ],
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
                            child: ListTile(
                              title: Row(
                                children: [
                                  Text(adm['patient_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Text('(${adm['patient_display_id']})', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                  const Spacer(),
                                  _buildIpdStatusBadge(adm['status']),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Ward: ${adm['ward_type']} | Bed: ${adm['bed_number'] ?? 'Unallocated'}\n'
                                  'Admission Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(adm['admission_date']).toLocal())}',
                                  style: const TextStyle(height: 1.3),
                                ),
                              ),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: active ? AppTheme.primaryColor : Colors.grey.shade100,
                                  foregroundColor: active ? Colors.white : Colors.black87,
                                  elevation: 0,
                                ),
                                icon: Icon(active ? Icons.receipt_long : Icons.visibility_outlined, size: 16),
                                label: Text(active ? 'Worksheet' : 'Receipt'),
                                onPressed: () => _openIpBillingWorksheet(adm),
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  onChanged: (val) => setState(() => _catalogSearch = val),
                  decoration: const InputDecoration(
                    hintText: 'Search catalog by Service Name or Category...',
                    prefixIcon: Icon(Icons.search),
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
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Text(service == null ? 'Add Service Item' : 'Edit Service Item', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
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
                          dropdownItems: const ['OP', 'IP', 'Lab', 'Pharmacy', 'General'],
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
                    try {
                      await _billingCtrl.saveBillingService(
                        name: _svcNameController.text.trim(),
                        category: _svcCategory,
                        price: double.parse(_svcPriceController.text.trim()),
                        description: _svcDescController.text.trim(),
                      );
                      Navigator.pop(ctx);
                      _loadCatalog();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service saved successfully!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
        List<Map<String, dynamic>> addedWorksheetItems = [];
        List<Map<String, dynamic>> advancesPaid = [];
        Map<String, dynamic>? activeInvoice;
        Map<String, dynamic> bedDetails = {};
        Map<String, dynamic> admission = {};
        bool loading = true;

        final TextEditingController ipSvcPriceCtrl = TextEditingController();
        final TextEditingController depositAmtCtrl = TextEditingController();
        final TextEditingController ipSvcQtyCtrl = TextEditingController(text: '1');
        String? selectedSvcId;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Future<void> fetchSummary() async {
              try {
                final summary = await _billingCtrl.fetchIpdBillingSummary(admissionId);
                setSheetState(() {
                  admission = summary['admission'] ?? {};
                  bedDetails = summary['bed_details'] ?? {};
                  activeInvoice = summary['invoice'];
                  addedWorksheetItems = List<Map<String, dynamic>>.from(summary['items'] ?? []);
                  // Filter out bed charge item from invoice list since we build and calculate it automatically
                  addedWorksheetItems.removeWhere((item) => item['item_name'].toString().contains('Bed Charge'));
                  advancesPaid = List<Map<String, dynamic>>.from(summary['payments'] ?? []);
                  loading = false;
                });
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            }

            if (loading) {
              fetchSummary();
              return const AlertDialog(
                backgroundColor: Colors.white,
                content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              );
            }

            // Calculation Logic
            final bedDays = bedDetails['days'] as int? ?? 1;
            final bedRate = double.parse((bedDetails['daily_rate'] ?? 0).toString());
            final bedTotal = bedDays * bedRate;

            double itemsTotal = 0;
            for (var item in addedWorksheetItems) {
              itemsTotal += double.parse(item['subtotal'].toString());
            }

            final totalAmount = bedTotal + itemsTotal;
            final double disc = activeInvoice != null ? double.parse(activeInvoice!['discount'].toString()) : 0.0;
            final netAmount = totalAmount - disc;

            double totalDeposits = 0;
            for (var pay in advancesPaid) {
              totalDeposits += double.parse(pay['amount'].toString());
            }

            final remainingBalance = netAmount - totalDeposits;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('IP Billing Worksheet - ${admission['patient_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              content: SizedBox(
                width: 900,
                height: MediaQuery.of(context).size.height * 0.8,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Items and services lists
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bed accommodation charges card
                            Card(
                              elevation: 0,
                              color: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Bed / Accommodation Charges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${bedDetails['ward_type']} Ward (Bed: ${bedDetails['bed_number']})', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text('₹${bedRate.toStringAsFixed(2)} / day'),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Admission Duration: $bedDays Days'),
                                        Text('₹${bedTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Added Services list
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('Other Added Services / Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Form to add custom/catalog service
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF1F7FB), borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: CustomDropdownSearch(
                                      label: '',
                                      hint: 'Select Service',
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
                                        // Save service item to database invoice
                                        // If no active invoice exists, create one first.
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
                            const SizedBox(height: 12),

                            if (addedWorksheetItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Center(child: Text('No additional service items added yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: addedWorksheetItems.length,
                                separatorBuilder: (c, i) => const Divider(),
                                itemBuilder: (scCtx, index) {
                                  final item = addedWorksheetItems[index];
                                  final qty = item['quantity'] as int? ?? 1;
                                  final price = double.parse(item['unit_price'].toString());
                                  final sub = qty * price;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('$qty x ₹${price.toStringAsFixed(2)}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('₹${sub.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          onPressed: () async {
                                            // Delete item from db
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
                                  );
                                },
                              )
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 32),

                    // Right Column: Summary worksheet and Deposits
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Worksheet billing calculation panel
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Column(
                              children: [
                                _buildSummaryRow('Bed Total (${bedDays} Days)', bedTotal),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Other Services', itemsTotal),
                                const Divider(height: 20),
                                _buildSummaryRow('Total Bill', totalAmount, isBold: true),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Discounts', disc, color: Colors.redAccent),
                                const Divider(height: 20),
                                _buildSummaryRow('Net Bill Amount', netAmount, isBold: true, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Deposits / Advances card
                          const Text('Advances & Deposits Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: TextFormField(
                                    controller: depositAmtCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: 'Enter Deposit Amount (₹)'),
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
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0),
                                child: const Text('Add Deposit'),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: advancesPaid.isEmpty
                                ? Center(child: Text('No deposits recorded.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)))
                                : ListView.builder(
                                    itemCount: advancesPaid.length,
                                    itemBuilder: (payCtx, index) {
                                      final pay = advancesPaid[index];
                                      final date = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(pay['payment_date']).toLocal());
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('₹${double.parse(pay['amount'].toString()).toStringAsFixed(2)} (${pay['payment_mode']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Remaining Balance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('₹${remainingBalance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: remainingBalance > 0 ? Colors.redAccent : Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openFinalDischargePanel(admissionId, remainingBalance, addedWorksheetItems, disc);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.logoRed, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                                  child: const Text('Discharge & Final Settle', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              )
                            ],
                          )
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
    );
  }

  void _openFinalDischargePanel(int admissionId, double balance, List<Map<String, dynamic>> items, double oldDiscount) {
    final TextEditingController summaryCtrl = TextEditingController();
    final TextEditingController balancePayCtrl = TextEditingController(text: balance.toStringAsFixed(0));
    final TextEditingController discCtrl = TextEditingController(text: oldDiscount.toStringAsFixed(0));
    final TextEditingController finalRefCtrl = TextEditingController();
    String payMode = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text('Final Discharge Settlement', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Discharge Summary *'),
                      TextFormField(controller: summaryCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'e.g. Patient successfully treated for acute appendicitis and discharged in stable condition.')),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Discount (₹)'),
                                TextFormField(
                                  controller: discCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    final d = double.tryParse(val) ?? 0.0;
                                    setDState(() {
                                      balancePayCtrl.text = (balance - (d - oldDiscount)).toStringAsFixed(0);
                                    });
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
                                _buildLabel('Collected Amount (₹)'),
                                TextFormField(controller: balancePayCtrl, keyboardType: TextInputType.number),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Payment Mode'),
                      Row(
                        children: ['Cash', 'Card', 'UPI', 'Insurance'].map((mode) {
                          final selected = payMode == mode;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(mode),
                              selected: selected,
                              selectedColor: AppTheme.primaryColor,
                              labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                              backgroundColor: Colors.grey.shade100,
                              onSelected: (val) {
                                if (val) setDState(() => payMode = mode);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Transaction Reference'),
                      TextFormField(controller: finalRefCtrl, decoration: const InputDecoration(hintText: 'Optional')),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(onPressed: () => Navigator.pop(ctx), style: AppTheme.cancelButton, child: const Text('Back')),
                ElevatedButton(
                  onPressed: () async {
                    if (summaryCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discharge Summary is required'), backgroundColor: Colors.red));
                      return;
                    }
                    try {
                      final discTotal = double.tryParse(discCtrl.text) ?? 0.0;

                      await _billingCtrl.dischargeAndSettleIP(
                        admissionId: admissionId,
                        dischargeSummary: summaryCtrl.text.trim(),
                        items: items.map((x) => {
                          'service_id': x['service_id'],
                          'item_name': x['item_name'],
                          'quantity': x['quantity'],
                          'unit_price': double.parse(x['unit_price'].toString())
                        }).toList(),
                        discount: discTotal,
                        finalPaymentMode: payMode,
                        transactionReference: finalRefCtrl.text.trim()
                      );

                      Navigator.pop(ctx);
                      _loadIpAdmissions();
                      _loadInvoices();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient discharged and billing settled!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error discharging: $e'), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.logoRed, foregroundColor: Colors.white, elevation: 0),
                  child: const Text('Confirm Discharge & Settle'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // ─── INVOICE RECEIPT / PRINT RECEIPT DIALOG ────────────────────────────────

  void _showInvoiceReceiptDialog(int invoiceId) async {
    bool showPaymentForm = false;
    String payMode = 'Cash';
    final TextEditingController collectAmtCtrl = TextEditingController();
    final TextEditingController collectRefCtrl = TextEditingController();
    final TextEditingController discountPercentCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) {
        Map<String, dynamic> invoiceData = {};
        bool loading = true;

        return StatefulBuilder(
          builder: (dCtx, setDState) {
            if (loading) {
              _billingCtrl.fetchInvoiceDetails(invoiceId).then((data) {
                setDState(() {
                  invoiceData = data;
                  loading = false;
                  final inv = invoiceData['invoice'] ?? {};
                  final double initialDiscount = double.tryParse((inv['discount'] ?? 0.0).toString()) ?? 0.0;
                  final double totalAmountVal = double.tryParse((inv['total_amount'] ?? 0.0).toString()) ?? 0.0;
                  final double initialPercent = totalAmountVal > 0 ? (initialDiscount / totalAmountVal) * 100.0 : 0.0;
                  discountPercentCtrl.text = initialPercent.toStringAsFixed(0);
                });
              }).catchError((e) {
                Navigator.pop(dCtx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading invoice: $e'), backgroundColor: Colors.red));
              });

              return const AlertDialog(
                backgroundColor: Colors.white,
                content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              );
            }

            final inv = invoiceData['invoice'] ?? {};
            final List items = invoiceData['items'] ?? [];
            final List payments = invoiceData['payments'] ?? [];

            final patientName = inv['patient_name'] ?? 'N/A';
            final patientDisplayId = inv['patient_display_id'] ?? 'N/A';
            final date = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(inv['created_at']).toLocal());

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Invoice & Receipt Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dCtx)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Print layout details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Receipt No: ${inv['invoice_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Date: $date', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Patient: $patientName ($patientDisplayId)', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Visit Type: ${inv['admission_type']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const Divider(height: 24, thickness: 1.2),
                      
                      const Text('Items Billed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                      const SizedBox(height: 8),
                      ...items.map((item) {
                        final qty = item['quantity'] as int? ?? 1;
                        final price = double.parse(item['unit_price'].toString());
                        final sub = qty * price;
                        return Padding(
                           padding: const EdgeInsets.symmetric(vertical: 4.0),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Expanded(child: Text(item['item_name'], style: const TextStyle(fontSize: 13))),
                               Text('$qty x ₹${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                               const SizedBox(width: 24),
                               Text('₹${sub.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                             ],
                           ),
                        );
                      }).toList(),
                      const Divider(height: 24),

                      _buildSummaryRow('Total Amount', double.parse(inv['total_amount'].toString())),
                      const SizedBox(height: 6),
                      _buildSummaryRow('Discount Offered', double.parse(inv['discount'].toString()), color: Colors.red),
                      const SizedBox(height: 6),
                      _buildSummaryRow('Net Amount Due', double.parse(inv['net_amount'].toString()), isBold: true, color: AppTheme.primaryColor),
                      const SizedBox(height: 6),
                      _buildSummaryRow('Paid Amount', double.parse(inv['paid_amount'].toString()), color: Colors.green),
                      
                      const Divider(height: 24),
                      const Text('Payments History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                      const SizedBox(height: 8),
                      payments.isEmpty
                          ? Center(child: Text('No payments recorded.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)))
                          : Column(
                              children: payments.map((pay) {
                                final pDate = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(pay['payment_date']).toLocal());
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('₹${double.parse(pay['amount'].toString()).toStringAsFixed(2)} (${pay['payment_mode']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(pDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                      
                      if (inv['payment_status'] != 'Paid') ...[
                        const Divider(height: 24),
                        if (!showPaymentForm)
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final net = double.parse(inv['net_amount'].toString());
                                final paid = double.parse(inv['paid_amount'].toString());
                                final due = net - paid;
                                collectAmtCtrl.text = due.toStringAsFixed(0);
                                setDState(() => showPaymentForm = true);
                              },
                              icon: const Icon(Icons.payment),
                              label: const Text('Collect Pending Payment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(200, 44),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Record Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('Discount (%)'),
                                          TextFormField(
                                            controller: discountPercentCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                            onChanged: (val) {
                                              final double pct = double.tryParse(val) ?? 0.0;
                                              final double total = double.parse(inv['total_amount'].toString());
                                              final double paid = double.parse(inv['paid_amount'].toString());
                                              final double discAmt = total * (pct / 100.0);
                                              final double net = total - discAmt;
                                              setDState(() {
                                                collectAmtCtrl.text = (net - paid).toStringAsFixed(0);
                                              });
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
                                          _buildLabel('Amount to Collect (₹) *'),
                                          TextFormField(
                                            controller: collectAmtCtrl,
                                            keyboardType: TextInputType.number,
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
                                    final selected = payMode == mode;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6.0),
                                      child: ChoiceChip(
                                        label: Text(mode, style: const TextStyle(fontSize: 12)),
                                        selected: selected,
                                        selectedColor: AppTheme.primaryColor,
                                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
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
                                  decoration: const InputDecoration(hintText: 'Optional', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => setDState(() => showPaymentForm = false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final double amt = double.tryParse(collectAmtCtrl.text) ?? 0;
                                        if (amt < 0) return;
                                        final double pct = double.tryParse(discountPercentCtrl.text) ?? 0.0;
                                        final double total = double.parse(inv['total_amount'].toString());
                                        final double discAmt = total * (pct / 100.0);
                                        try {
                                          await _billingCtrl.recordPayment(
                                            invoiceId: invoiceId,
                                            amount: amt,
                                            paymentMode: payMode,
                                            transactionReference: collectRefCtrl.text.trim(),
                                            discount: discAmt,
                                          );
                                          
                                          ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!'), backgroundColor: Colors.green));
                                          
                                          setDState(() {
                                            loading = true;
                                            showPaymentForm = false;
                                            collectAmtCtrl.clear();
                                            collectRefCtrl.clear();
                                          });
                                          _loadInvoices();
                                        } catch (e) {
                                          ScaffoldMessenger.of(dCtx).showSnackBar(SnackBar(content: Text('Error recording payment: $e'), backgroundColor: Colors.red));
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                                      child: const Text('Submit Payment'),
                                    )
                                  ],
                                )
                              ],
                            ),
                          )
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Trigger native print helper or dialog
                    ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(content: Text('Print job sent to default printer.')));
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Print Receipt'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('₹${value.toStringAsFixed(2)}', style: style),
      ],
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
    final filtered = _invoices.where((inv) {
      if (inv['admission_type'] != 'HomeVisit') return false;
      final q = _invoiceSearch.toLowerCase();
      final matchQuery = (inv['invoice_number'] ?? '').toString().toLowerCase().contains(q) ||
          (inv['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
          (inv['patient_display_id'] ?? '').toString().toLowerCase().contains(q);

      if (!matchQuery) return false;

      if (_homeCareStatusFilter == 'Unpaid') {
        return inv['payment_status'] == 'Unpaid' || inv['payment_status'] == 'Pending';
      } else if (_homeCareStatusFilter == 'Paid') {
        return inv['payment_status'] == 'Paid' || inv['payment_status'] == 'Settled';
      }
      return true;
    }).toList();

    double totalBilled = filtered.fold(0.0, (sum, inv) => sum + (double.tryParse(inv['net_amount'].toString()) ?? 0.0));
    double totalPaid = filtered.fold(0.0, (sum, inv) => sum + (double.tryParse(inv['paid_amount'].toString()) ?? 0.0));
    int unpaidCount = filtered.where((inv) => inv['payment_status'] != 'Paid' && inv['payment_status'] != 'Settled').length;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard('Home Care Invoices', '${filtered.length}', Icons.receipt_long, AppTheme.primaryColor, isMobile),
                const SizedBox(width: 12),
                _buildStatCard('Total Billed Amount', '₹${totalBilled.toStringAsFixed(2)}', Icons.payments_outlined, AppTheme.secondaryColor, isMobile),
                const SizedBox(width: 12),
                _buildStatCard('Total Collected', '₹${totalPaid.toStringAsFixed(2)}', Icons.check_circle_outline, Colors.teal, isMobile),
                const SizedBox(width: 12),
                _buildStatCard('Pending Payment Bills', '$unpaidCount', Icons.pending_actions, AppTheme.dangerColor, isMobile),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  onChanged: (val) => setState(() => _invoiceSearch = val),
                  decoration: const InputDecoration(
                    hintText: 'Search Home Care Invoices by Invoice #, Patient Name, or ID...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _homeCareStatusFilter,
                    items: ['All', 'Unpaid', 'Paid'].map((st) => DropdownMenuItem(value: st, child: Text('Status: $st', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _homeCareStatusFilter = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _loadInvoices,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Invoices List
          Expanded(
            child: _isLoadingInvoices
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
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
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final inv = filtered[index];
                          final double net = double.tryParse(inv['net_amount'].toString()) ?? 0.0;
                          final double paid = double.tryParse(inv['paid_amount'].toString()) ?? 0.0;
                          final String pStatus = inv['payment_status'] ?? 'Unpaid';
                          final bool isPaid = pStatus == 'Paid' || pStatus == 'Settled';

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
                              child: Row(
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
                                            Text(inv['invoice_number'] ?? 'INV-HV', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
                                            const SizedBox(width: 10),
                                            _buildPaymentStatusBadge(pStatus),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Patient: ${inv['patient_name'] ?? "N/A"} (${inv['patient_display_id'] ?? ""})',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Service Date: ${inv['created_at'] != null ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(inv['created_at']).toLocal()) : "Today"}',
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
                                            label: const Text('View Bill & Items', style: TextStyle(fontSize: 12)),
                                            onPressed: () => _showInvoiceReceiptDialog(inv['id']),
                                          ),
                                          if (!isPaid) ...[
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              style: AppTheme.primaryButton,
                                              icon: const Icon(Icons.payments, size: 14),
                                              label: const Text('Collect Payment', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showInvoiceReceiptDialog(inv['id']),
                                            ),
                                          ],
                                        ],
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      width: isMobile ? 160 : 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
