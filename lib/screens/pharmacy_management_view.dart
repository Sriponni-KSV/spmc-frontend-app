import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_dropdown_search.dart';

class PharmacyManagementView extends StatefulWidget {
  final bool isMobile;
  const PharmacyManagementView({super.key, this.isMobile = false});

  @override
  State<PharmacyManagementView> createState() => _PharmacyManagementViewState();
}

class _PharmacyManagementViewState extends State<PharmacyManagementView>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  // Data
  List<dynamic> _prescriptions = [];
  List<dynamic> _controlledDrugs = [];
  List<dynamic> _inventory = [];
  List<dynamic> _lowStockItems = [];
  List<dynamic> _expiringItems = [];
  List<dynamic> _activityFeed = [];

  Map<String, dynamic>? _selectedPrescription;

  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _ctrlSearchController = TextEditingController();
  String _ctrlSearchQuery = '';
  String _selectedCtrlCategory = 'All';
  int _ctrlPage = 0;
  final int _itemsPerPage = 10;

  // Per-item quantity overrides for dispense
  final Map<int, TextEditingController> _qtyControllers = {};

  String get baseUrl => ApiEndpoints.baseUrl;

  @override
  void initState() {
    super.initState();
    _tabController ??= TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _ctrlSearchController.dispose();
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final responses = await Future.wait([
        ApiService.get('$baseUrl/pharmacy/prescriptions'),
        ApiService.get('$baseUrl/pharmacy/controlled-drugs'),
        ApiService.get('$baseUrl/inventory/items'),
        ApiService.get('$baseUrl/inventory/alerts'),
        ApiService.get('$baseUrl/pharmacy/stats'),
        ApiService.get('$baseUrl/pharmacy/activity'),
      ]);

      final presBody    = ApiService.decodeJsonResponse(responses[0]);
      final ctrlBody    = ApiService.decodeJsonResponse(responses[1]);
      final invBody     = ApiService.decodeJsonResponse(responses[2]);
      final alertBody   = ApiService.decodeJsonResponse(responses[3]);
      // responses[4] = stats (unused; stats computed locally)
      final actBody     = ApiService.decodeJsonResponse(responses[5]);

      if (mounted) {
        final pList = List<dynamic>.from(presBody['data'] ?? []);

        // Sort all prescriptions by created_at descending to find the latest
        final sorted = List<dynamic>.from(pList)
          ..sort((a, b) {
            final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
            final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

        // Auto-select the most recently prescribed or dispensed prescription
        Map<String, dynamic>? sel;
        if (sorted.isNotEmpty) {
          sel = sorted.first as Map<String, dynamic>;
        }

        setState(() {
          _prescriptions   = pList;
          _controlledDrugs = List<dynamic>.from(ctrlBody['data'] ?? []);
          _inventory       = List<dynamic>.from(invBody['data'] ?? []);
          _lowStockItems   = List<dynamic>.from(alertBody['data']?['low_stock'] ?? []);
          _expiringItems   = List<dynamic>.from(alertBody['data']?['expiring'] ?? []);

          _activityFeed    = List<dynamic>.from(actBody['data'] ?? []);
          _selectedPrescription = sel;
          _isLoading = false;
        });
        _initQtyControllers(sel);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  void _initQtyControllers(Map<String, dynamic>? pres) {
    for (var c in _qtyControllers.values) { c.dispose(); }
    _qtyControllers.clear();
    if (pres == null) return;
    final items = pres['items'] as List<dynamic>? ?? [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final qty = _calculateQuantity(
        item['frequency'] ?? '', item['duration'] ?? '',
        item['dosage'] ?? '', item['name'] ?? '',
      );
      _qtyControllers[i] = TextEditingController(text: qty.toString());
    }
  }

  // ─── Dosage/quantity logic ─────────────────────────────────────────────────

  Map<String, dynamic>? _parseDosageOrStrength(String str) {
    if (str.isEmpty) return null;
    final clean = str.toLowerCase().trim();
    final match = RegExp(r'^(\d+(?:\.\d+)?)\s*(mg|g|mcg|ml|iu|cap|tab|pcs|piece|tablet|capsule)?s?$').firstMatch(clean) ??
                  RegExp(r'(\d+(?:\.\d+)?)\s*(mg|g|mcg|ml|iu|cap|tab|pcs|piece|tablet|capsule)?s?').firstMatch(clean);
    if (match != null) {
      return {'value': double.tryParse(match.group(1) ?? '1.0') ?? 1.0, 'unit': match.group(2) ?? 'tab'};
    }
    return null;
  }

  Map<String, dynamic>? _parseStrengthFromName(String name) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(mg|g|mcg|ml|iu)').firstMatch(name.toLowerCase());
    if (match != null) {
      return {'value': double.tryParse(match.group(1) ?? '1.0') ?? 1.0, 'unit': match.group(2) ?? 'mg'};
    }
    return null;
  }

  double _getDosageMultiplier(String dosageStr, String medicineName) {
    final dosage = _parseDosageOrStrength(dosageStr);
    if (dosage == null) return 1.0;
    final isCountUnit = ['cap', 'tab', 'pcs', 'piece', 'tablet', 'capsule'].contains(dosage['unit']);
    if (isCountUnit) return (dosage['value'] as num).toDouble();
    final medStrength = _parseStrengthFromName(medicineName);
    if (medStrength == null) return 1.0;
    double norm(double v, String u) { if (u == 'g') return v * 1000; if (u == 'mcg') return v / 1000; return v; }
    final weightUnits = ['mg', 'g', 'mcg'];
    if (weightUnits.contains(dosage['unit']) && weightUnits.contains(medStrength['unit'])) {
      final nd = norm((dosage['value'] as num).toDouble(), dosage['unit'] as String);
      final nm = norm((medStrength['value'] as num).toDouble(), medStrength['unit'] as String);
      if (nm > 0) return nd / nm;
    } else if (dosage['unit'] == medStrength['unit']) {
      final vm = (medStrength['value'] as num).toDouble();
      if (vm > 0) return (dosage['value'] as num).toDouble() / vm;
    }
    return 1.0;
  }

  int _calculateQuantity(String frequency, String duration, String dosage, String medicineName) {
    int dailyCount = 1;
    final freq = frequency.toLowerCase().trim();
    if (RegExp(r'^\d(-\d)+$').hasMatch(freq)) {
      dailyCount = freq.split('-').fold(0, (s, p) => s + (int.tryParse(p) ?? 0));
      if (dailyCount == 0) dailyCount = 1;
    } else if (freq.contains('once') || freq == '1-0-0' || freq == '0-0-1') { dailyCount = 1;
    } else if (freq.contains('twice') || freq.contains('bd') || freq.contains('bid')) { dailyCount = 2;
    } else if (freq.contains('thrice') || freq.contains('tds') || freq.contains('tid')) { dailyCount = 3;
    } else if (freq.contains('four') || freq.contains('qds') || freq.contains('qid')) { dailyCount = 4;
    } else {
      final m = RegExp(r'(\d+)\s*time').firstMatch(freq);
      if (m != null) dailyCount = int.tryParse(m.group(1) ?? '1') ?? 1;
    }
    int days = 1;
    final dur = duration.toLowerCase().trim();
    final nm = RegExp(r'(\d+)').firstMatch(dur);
    if (nm != null) {
      final v = int.tryParse(nm.group(1) ?? '1') ?? 1;
      days = dur.contains('week') ? v * 7 : dur.contains('month') ? v * 30 : v;
    } else {
      days = dur.contains('week') ? 7 : dur.contains('month') ? 30 : 1;
    }
    return (dailyCount * days * _getDosageMultiplier(dosage, medicineName)).ceil();
  }

  /// Normalise a drug name for fuzzy matching:
  /// lowercases, strips punctuation, and collapses whitespace.
  String _normDrug(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Map<String, dynamic> _checkItemStock(String name, String dosage, int neededQty) {
    final normP = _normDrug(name);
    final normD = _normDrug(dosage);
    dynamic match;

    // Pass 1 – exact normalised name match
    for (var item in _inventory) {
      if (_normDrug(item['name'].toString()) == normP) { match = item; break; }
    }

    // Pass 2 – inventory name contains prescribed name (or vice-versa)
    if (match == null) {
      for (var item in _inventory) {
        final n = _normDrug(item['name'].toString());
        if (n.contains(normP) || normP.contains(n)) { match = item; break; }
      }
    }

    // Pass 3 – first-word prefix match (e.g. "amox" matches "amoxicillin 500mg")
    if (match == null && normP.length >= 4) {
      final prefix = normP.substring(0, (normP.length * 0.6).round().clamp(4, normP.length));
      for (var item in _inventory) {
        final n = _normDrug(item['name'].toString());
        if (n.startsWith(prefix) || normP.startsWith(_normDrug(item['name'].toString()).substring(0, (_normDrug(item['name'].toString()).length * 0.6).round().clamp(4, _normDrug(item['name'].toString()).length)))) {
          match = item; break;
        }
      }
    }

    // Pass 4 – dosage-aware match (name + dosage both present in inventory name)
    if (match == null && normD.isNotEmpty) {
      for (var item in _inventory) {
        final n = _normDrug(item['name'].toString());
        if (n.contains(normP) && n.contains(normD)) { match = item; break; }
      }
    }

    // Find alternative if insufficient stock
    dynamic alternative;
    if (match != null && (match['quantity'] ?? 0) < neededQty) {
      for (var item in _inventory) {
        if (item['id'] == match['id']) continue;
        final cat = (item['category'] ?? '').toString();
        if (cat == 'Medicine' && (item['quantity'] ?? 0) > 0) { alternative = item; break; }
      }
    }

    if (match == null) {
      return {'available': false, 'qty': 0, 'registered': false, 'name': name, 'unit': 'pcs',
              'is_controlled': false, 'expiry_date': null, 'alternative': null};
    }

    final int qty = (match['quantity'] ?? match['qty'] ?? 0) as int;
    return {
      'available': qty >= neededQty,
      'qty': qty,
      'registered': true,
      'name': match['name'] ?? name,
      'unit': (match['unit'] ?? 'pcs').toString(),
      'is_controlled': match['is_controlled'] == true,
      'expiry_date': match['expiry_date'],
      'alternative': alternative != null
          ? {'name': alternative['name'], 'qty': alternative['quantity'] ?? 0, 'unit': alternative['unit'] ?? 'pcs'}
          : null,
    };
  }

  Future<void> _dispensePrescription(Map<String, dynamic> prescription) async {
    final clientItems = prescription['items'] as List<dynamic>;
    final dispenseItems = <Map<String, dynamic>>[];
    for (int i = 0; i < clientItems.length; i++) {
      final item = clientItems[i];
      final drugName = item['name'] ?? '';
      final dosage = item['dosage'] ?? '';
      final ctrlQty = _qtyControllers[i]?.text ?? '';
      final qty = int.tryParse(ctrlQty) ??
          _calculateQuantity(item['frequency'] ?? '', item['duration'] ?? '', dosage, drugName);
      dispenseItems.add({'name': drugName, 'dosage': dosage, 'quantity': qty});
    }
    try {
      final response = await ApiService.post('$baseUrl/pharmacy/dispense', {
        'id': prescription['id'],
        'type': prescription['type'],
        'items': dispenseItems,
      });
      final body = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 200 && body['success'] == true) {
        if (!mounted) return;
        final alerts = List<dynamic>.from(body['alerts'] ?? []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(alerts.isNotEmpty
              ? 'Dispensed! ⚠️ ${alerts.first}'
              : '✅ Prescription dispensed successfully!'),
          backgroundColor: alerts.isNotEmpty ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 4),
        ));
        _loadAll();
      } else {
        throw Exception(body['message'] ?? 'Failed to dispense');
      }
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cleanMsg), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
      ]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(widget.isMobile ? 16 : 24, 24, widget.isMobile ? 16 : 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Pharmacy Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Dispensing · Stock Monitoring · Controlled Drug Audit',
                    style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
              ]),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                onPressed: _loadAll,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // ── Tabs ────────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: TabBar(
            controller: _tabController!,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            tabs: [
              const Tab(text: 'Dashboard'),
              Tab(
                text: widget.isMobile
                    ? 'Rx (${_prescriptions.where((p) => p["pharmacy_status"] == "Pending").length})'
                    : 'Prescriptions (${_prescriptions.where((p) => p["pharmacy_status"] == "Pending").length})',
              ),
              Tab(
                text: widget.isMobile
                    ? 'Ctrl (${_controlledDrugs.length})'
                    : 'Controlled Drugs (${_controlledDrugs.length})',
              ),
              Tab(
                text: widget.isMobile
                    ? 'Alerts (${_lowStockItems.length + _expiringItems.length})'
                    : 'Expiry & Alerts (${_lowStockItems.length + _expiringItems.length})',
              ),
            ],
          ),
        ),

        // ── Tab Views ───────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController!,
            children: [
              _buildDashboardTab(),
              _buildPrescriptionsTab(),
              _buildControlledDrugsTab(),
              _buildExpiryAlertsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 0: DASHBOARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stats cards
        _buildStatsCards(),
        const SizedBox(height: 28),

        // Two columns on desktop, stacked on mobile
        if (widget.isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecentActivityPanel(),
              const SizedBox(height: 20),
              _buildAlertsSummaryPanel(),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildRecentActivityPanel()),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: _buildAlertsSummaryPanel()),
            ],
          ),
      ]),
    );
  }

  Widget _buildStatsCards() {
    final now = DateTime.now();

    // Compute from live data for accuracy
    final todayPrescriptions = _prescriptions.where((p) {
      final createdAtStr = p['created_at']?.toString();
      if (createdAtStr == null) return false;
      final dt = DateTime.tryParse(createdAtStr)?.toLocal();
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).length;

    final pendingOrders = _prescriptions
        .where((p) => p['pharmacy_status'] != 'Dispensed')
        .length;

    final dispensedToday = _prescriptions.where((p) {
      if (p['pharmacy_status'] != 'Dispensed') return false;
      final updatedAtStr = p['updated_at']?.toString() ?? p['created_at']?.toString();
      if (updatedAtStr == null) return false;
      final dt = DateTime.tryParse(updatedAtStr)?.toLocal();
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).length;

    final cards = [
      _StatCard('Today\'s Prescriptions', '$todayPrescriptions',
          Icons.receipt_long_outlined, const Color(0xFF2563EB), 'All OPD + IPD'),
      _StatCard('Pending Orders', '$pendingOrders',
          Icons.pending_actions_outlined, const Color(0xFFF59E0B), 'Awaiting dispensing'),
      _StatCard('Dispensed Today', '$dispensedToday',
          Icons.check_circle_outline, const Color(0xFF16A34A), 'Completed today'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.isMobile ? 1 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: widget.isMobile ? 3.0 : 2.6,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _buildStatCard(cards[i]),
    );
  }

  Widget _buildStatCard(_StatCard card) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: card.color),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(card.icon, color: card.color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card.value,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: card.color,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.sub,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondaryColor,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildRecentActivityPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(children: [
            const Icon(Icons.history_rounded, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 8),
            const Text('Recent Dispensing Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
        const Divider(height: 1),
        if (_activityFeed.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No dispensing activity yet', style: TextStyle(color: Colors.grey))),
          )
        else
          ...(_activityFeed.take(10).map((act) => _buildActivityItem(act))),
      ]),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> act) {
    final isOpd = act['type'] == 'outpatient';
    final time = act['dispensed_at'] != null
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(act['dispensed_at']).toLocal())
        : '--';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (isOpd ? Colors.blue : Colors.purple).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(isOpd ? Icons.personal_injury_outlined : Icons.hotel_outlined,
                color: isOpd ? Colors.blue : Colors.purple, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(act['patient_name'] ?? 'Patient',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(act['medicine_summary'] ?? '',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.successBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15)),
              ),
              child: const Text('DISPENSED', style: TextStyle(fontSize: 8, color: AppTheme.successColor, fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ),
      const Divider(height: 1, indent: 20, endIndent: 20),
    ]);
  }

  Widget _buildAlertsSummaryPanel() {
    return Column(children: [
      // Low stock summary
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.dangerColor, size: 16),
              const SizedBox(width: 8),
              const Text('Low Stock Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.dangerBg, borderRadius: BorderRadius.circular(10)),
                child: Text('${_lowStockItems.length}', style: const TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ]),
          ),
          const Divider(height: 1),
          if (_lowStockItems.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('All stock levels are healthy ✅', style: TextStyle(color: Colors.grey, fontSize: 12)))
          else
            ...(_lowStockItems.take(5).map((item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                Text('${item['quantity'] ?? 0} / ${item['threshold'] ?? 0}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.dangerColor, fontWeight: FontWeight.bold)),
              ]),
            ))),
        ]),
      ),
      const SizedBox(height: 16),
      // Expiring summary
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              const Icon(Icons.event_busy_outlined, color: AppTheme.warningColor, size: 16),
              const SizedBox(width: 8),
              const Text('Expiring Soon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.warningBg, borderRadius: BorderRadius.circular(10)),
                child: Text('${_expiringItems.length}', style: const TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ]),
          ),
          const Divider(height: 1),
          if (_expiringItems.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No medicines expiring soon ✅', style: TextStyle(color: Colors.grey, fontSize: 12)))
          else
            ...(_expiringItems.take(5).map((item) {
              DateTime? exp;
              try { exp = DateTime.parse(item['expiry_date']); } catch (_) {}
              final daysLeft = exp != null ? exp.difference(DateTime.now()).inDays : null;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  Text(daysLeft != null ? '${daysLeft}d left' : 'Unknown',
                      style: TextStyle(fontSize: 11,
                          color: (daysLeft ?? 100) <= 7 ? AppTheme.dangerColor : AppTheme.warningColor,
                          fontWeight: FontWeight.bold)),
                ]),
              );
            })),
        ]),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: PRESCRIPTIONS QUEUE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPrescriptionsTab() {
    final filtered = _prescriptions.where((p) {
      final q = _searchQuery.toLowerCase();
      return (p['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
             (p['patient_display_id'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    // On mobile, show master-detail toggle
    if (widget.isMobile) {
      if (_selectedPrescription != null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button header
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedPrescription = null;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, color: AppTheme.primaryColor, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Back to Prescriptions',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildPrescriptionDetail(),
              ),
            ],
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPrescriptionList(filtered),
        );
      }
    }

    // On desktop, show side-by-side view
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: _buildPrescriptionList(filtered),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: _selectedPrescription == null
                ? _buildLastActivityPanel()
                : _buildPrescriptionDetail(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionList(List<dynamic> filtered) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search patient name or ID…',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  )
                : null,
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Card(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No prescriptions found.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final pres = filtered[i];
                final isSelected = _selectedPrescription != null &&
                    _selectedPrescription!['id'] == pres['id'] &&
                    _selectedPrescription!['type'] == pres['type'];
                final isDispensed = pres['pharmacy_status'] == 'Dispensed';
                final createdAtStr = pres['created_at']?.toString();
                final isToday = createdAtStr != null &&
                    DateTime.tryParse(createdAtStr)?.toLocal().year == DateTime.now().year &&
                    DateTime.tryParse(createdAtStr)?.toLocal().month == DateTime.now().month &&
                    DateTime.tryParse(createdAtStr)?.toLocal().day == DateTime.now().day;

                return Card(
                  color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isToday ? AppTheme.logoRed : AppTheme.borderColor),
                      width: (isSelected || isToday) ? 1.5 : 1.0,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _selectedPrescription = pres);
                      _initQtyControllers(pres);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (pres['type'] == 'outpatient' ? Colors.blue : Colors.purple).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              pres['type'] == 'outpatient' ? Icons.personal_injury_outlined : Icons.hotel_outlined,
                              color: pres['type'] == 'outpatient' ? Colors.blue : Colors.purple,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pres['patient_name'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isToday) ...[
                                      const SizedBox(width: 4),
                                      _statusBadge('TODAY', AppTheme.logoRed),
                                    ],
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pres['patient_display_id'] ?? '--',
                                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dr. ${pres['doctor_name'] ?? '--'}',
                                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(
                            isDispensed ? 'DISPENSED' : 'PENDING',
                            isDispensed ? AppTheme.successColor : Colors.amber.shade800,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
  Widget _buildLastActivityPanel() {
    // Find the most recently created prescription
    if (_prescriptions.isEmpty) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: const Center(
          child: Text('No prescriptions yet.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final sorted = List<dynamic>.from(_prescriptions)
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

    // Most recently dispensed
    final lastDispensed = sorted.firstWhere(
      (p) => p['pharmacy_status'] == 'Dispensed',
      orElse: () => null,
    );
    // Most recently prescribed (any status)
    final lastPrescribed = sorted.first;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedPrescription = lastPrescribed as Map<String, dynamic>;
                      _initQtyControllers(_selectedPrescription);
                    });
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('View Latest'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor, textStyle: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),

            // Last Prescribed card
            _buildActivitySummaryCard(
              label: 'Last Prescribed',
              icon: Icons.medical_services_outlined,
              iconColor: const Color(0xFF2563EB),
              pres: lastPrescribed as Map<String, dynamic>,
            ),

            if (lastDispensed != null) ...[
              const SizedBox(height: 16),
              _buildActivitySummaryCard(
                label: 'Last Dispensed',
                icon: Icons.check_circle_outline,
                iconColor: AppTheme.successColor,
                pres: lastDispensed as Map<String, dynamic>,
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              'Select any prescription from the list to review and dispense.',
              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySummaryCard({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Map<String, dynamic> pres,
  }) {
    final isDispensed = pres['pharmacy_status'] == 'Dispensed';
    final isOpd = pres['type'] == 'outpatient';
    final items = (pres['items'] as List<dynamic>? ?? []);
    final createdAtStr = pres['created_at']?.toString();
    final timeStr = createdAtStr != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(createdAtStr).toLocal())
        : '--';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedPrescription = pres;
          _initQtyControllers(_selectedPrescription);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDispensed
              ? AppTheme.successColor.withValues(alpha: 0.3)
              : AppTheme.primaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 15),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.4)),
                const Spacer(),
                _statusBadge(isDispensed ? 'DISPENSED' : 'PENDING',
                    isDispensed ? AppTheme.successColor : Colors.amber.shade800),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              pres['patient_name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   '${pres['patient_display_id'] ?? '--'} • ${isOpd ? 'OPD' : 'IPD'}',
                   style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                 ),
                 const SizedBox(height: 2),
                 Text(
                   'Dr. ${pres['doctor_name'] ?? '--'}',
                   style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w500),
                 ),
               ],
             ),
            const SizedBox(height: 6),
            Text(
              timeStr,
              style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...items.take(3).map<Widget>((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        '${item['name'] ?? ''} ${item['dosage'] ?? ''}'.trim(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    );
                  }),
                  if (items.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('+${items.length - 3} more',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionDetail() {

    final pres = _selectedPrescription!;
    final items = (pres['items'] as List<dynamic>? ?? []);
    final isDispensed = pres['pharmacy_status'] == 'Dispensed';
    final isOpd = pres['type'] == 'outpatient';

    final createdAtStr = pres['created_at']?.toString();
    final isToday = createdAtStr != null &&
        DateTime.tryParse(createdAtStr)?.toLocal().year == DateTime.now().year &&
        DateTime.tryParse(createdAtStr)?.toLocal().month == DateTime.now().month &&
        DateTime.tryParse(createdAtStr)?.toLocal().day == DateTime.now().day;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isToday) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBg,
                  border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'NEW MEDICATION PRESCRIBED TODAY',
                      style: const TextStyle(
                        color: AppTheme.dangerColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pres['patient_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pres['patient_display_id'] ?? '--'} • ${isOpd ? 'Outpatient' : 'Inpatient'}',
                            style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prescribed by Dr. ${pres['doctor_name'] ?? '--'}',
                            style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusBadge(
                  isDispensed ? 'DISPENSED' : 'PENDING',
                  isDispensed ? AppTheme.successColor : Colors.amber.shade800,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pres['created_at'] != null
                  ? 'Prescribed: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(pres['created_at']).toLocal())}'
                  : '',
              style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
            ),

            const SizedBox(height: 16),

            // Prescribed items with stock check
            const Text('Prescribed Medications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...List.generate(items.length, (i) {
              final item = items[i];
              final drugName = (item['name'] ?? '').toString();
              final dosage   = (item['dosage'] ?? '').toString();
              final freq     = (item['frequency'] ?? '').toString();
              final dur      = (item['duration'] ?? '').toString();
              final autoQty  = _calculateQuantity(freq, dur, dosage, drugName);
              final stock    = _checkItemStock(
                drugName,
                dosage,
                _qtyControllers[i] != null
                    ? (int.tryParse(_qtyControllers[i]!.text) ?? autoQty)
                    : autoQty,
              );
              final displayUnit = stock['unit'].toString().replaceAll(RegExp(r'^\d+\s*'), '');

              final cardBg = stock['available'] == true ? AppTheme.successBg : AppTheme.dangerBg;
              final cardBorderColor = isToday
                  ? AppTheme.logoRed.withValues(alpha: 0.6)
                  : (stock['available'] == true
                      ? AppTheme.successColor.withValues(alpha: 0.25)
                      : AppTheme.dangerColor.withValues(alpha: 0.25));
              final stockTextColor = stock['available'] == true ? AppTheme.successColor : AppTheme.dangerColor;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorderColor, width: isToday ? 1.5 : 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            drugName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        if (isToday) ...[
                          _statusBadge('NEW TODAY', AppTheme.logoRed),
                          const SizedBox(width: 8),
                        ],
                        if (stock['is_controlled'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 10, color: AppTheme.dangerColor),
                                SizedBox(width: 3),
                                Text(
                                  'CONTROLLED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: AppTheme.dangerColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Icon(
                          stock['available'] == true ? Icons.check_circle : Icons.error_outline,
                          color: stockTextColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stock['registered'] == true
                              ? 'Stock: ${stock['qty']} $displayUnit'
                              : 'Not in inventory',
                          style: TextStyle(
                            fontSize: 11,
                            color: stockTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (dosage.isNotEmpty) _infoChip('Dose: $dosage', Icons.medication_outlined),
                        if (freq.isNotEmpty) _infoChip('Freq: $freq', Icons.schedule_outlined),
                        if (dur.isNotEmpty) _infoChip('Dur: $dur', Icons.calendar_today_outlined),
                      ],
                    ),
                    // Expiry date
                    if (stock['expiry_date'] != null) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (_) {
                          DateTime? exp;
                          try {
                            exp = DateTime.parse(stock['expiry_date']);
                          } catch (_) {}
                          final daysLeft = exp != null ? exp.difference(DateTime.now()).inDays : null;
                          final isExpired = (daysLeft ?? 1) < 0;
                          final color = isExpired
                              ? AppTheme.dangerColor
                              : (daysLeft ?? 100) <= 7
                                  ? AppTheme.warningColor
                                  : AppTheme.textSecondaryColor;
                          return Row(
                            children: [
                              Icon(Icons.event, size: 12, color: color),
                              const SizedBox(width: 4),
                              Text(
                                isExpired
                                    ? 'EXPIRED ${DateFormat('dd MMM yyyy').format(exp!)}'
                                    : 'Expiry: ${exp != null ? DateFormat('dd MMM yyyy').format(exp) : 'Unknown'} (${daysLeft}d)',
                                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    // Alternative suggestion
                    if (stock['alternative'] != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, size: 13, color: AppTheme.infoColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Alt: ${stock['alternative']['name']} (${stock['alternative']['qty']} ${stock['alternative']['unit']} available)',
                                style: const TextStyle(fontSize: 11, color: AppTheme.infoColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Quantity editor
                    if (!isDispensed) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Qty to Dispense:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            height: 32,
                            child: TextFormField(
                              controller: _qtyControllers[i] ??= TextEditingController(text: autoQty.toString()),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(displayUnit, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),
            // Dispense / Already dispensed
            if (!isDispensed)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => _dispensePrescription(pres),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Confirm & Dispense Medications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check, color: AppTheme.successColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'This prescription has already been dispensed',
                      style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: CONTROLLED DRUGS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildControlledDrugsTab() {
    final categories = ['All', ..._controlledDrugs.map((c) => c['category']?.toString() ?? 'N/A').toSet().where((c) => c.isNotEmpty && c.toLowerCase() != 'food' && c.toLowerCase() != 'food item' && c.toLowerCase() != 'food items' && c.toLowerCase() != 'food stock')];

    final filtered = _controlledDrugs.where((item) {
      if (_selectedCtrlCategory != 'All' &&
          (item['category']?.toString() != _selectedCtrlCategory)) {
        return false;
      }
      if (_ctrlSearchQuery.trim().isNotEmpty) {
        final query = _ctrlSearchQuery.toLowerCase();
        final matches = (item['name']?.toString().toLowerCase().contains(query) ?? false) ||
            (item['category']?.toString().toLowerCase().contains(query) ?? false);
        if (!matches) return false;
      }
      return true;
    }).toList();

    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_ctrlPage >= totalPages && totalPages > 0) {
      _ctrlPage = totalPages - 1;
    }
    if (_ctrlPage < 0) _ctrlPage = 0;

    final paginated = filtered
        .skip(_ctrlPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock_outlined, color: Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 8),
          const Text('Controlled Drug Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${filtered.length} items',
              style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrlSearchController,
                        onChanged: (v) => setState(() {
                          _ctrlSearchQuery = v;
                          _ctrlPage = 0;
                        }),
                        decoration: const InputDecoration(
                          hintText: 'Search controlled drugs...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_ctrlSearchQuery.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            _ctrlSearchController.clear();
                            setState(() {
                              _ctrlSearchQuery = '';
                              _ctrlPage = 0;
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: CustomDropdownSearch(
                label: '',
                value: _selectedCtrlCategory,
                dropdownItems: categories,
                height: 44,
                borderColor: AppTheme.borderColor,
                borderWidth: 1.0,
                focusedBorderColor: AppTheme.primaryColor,
                focusedBorderWidth: 1.0,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCtrlCategory = val;
                      _ctrlPage = 0;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: Text('No controlled drugs matching criteria', style: TextStyle(color: Colors.grey))))
        else ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor, fontSize: 12),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 52,
                  columns: const [
                    DataColumn(label: Text('S.No')),
                    DataColumn(label: Text('Item Name')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Stock')),
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Expiry Date')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: paginated.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final qty = (item['quantity'] ?? 0) as int;
                    final threshold = (item['threshold'] ?? 10) as int;
                    final isLow = qty <= threshold;
                    DateTime? expiry;
                    try { if (item['expiry_date'] != null) expiry = DateTime.parse(item['expiry_date']); } catch (_) {}
                    final isExpired = expiry != null && expiry.isBefore(DateTime.now());
                    final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : null;

                    return DataRow(
                      color: WidgetStateProperty.resolveWith((states) {
                        if (isExpired) return AppTheme.dangerBg;
                        if (isLow) return AppTheme.warningBg;
                        return null;
                      }),
                      cells: [
                        DataCell(Text('${(index + 1) + (_ctrlPage * _itemsPerPage)}', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataCell(Text(item['category'] ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(Text('$qty', style: TextStyle(
                            color: isLow ? AppTheme.dangerColor : AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.bold))),
                        DataCell(Text(item['unit'] ?? '', style: const TextStyle(fontSize: 12))),
                        DataCell(expiry == null
                            ? const Text('N/A', style: TextStyle(color: Colors.grey, fontSize: 11))
                            : Text(
                                isExpired ? '⚠ EXPIRED' : '${DateFormat('dd MMM yyyy').format(expiry)} (${daysLeft}d)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isExpired
                                        ? AppTheme.dangerColor
                                        : (daysLeft ?? 100) <= 7
                                            ? AppTheme.warningColor
                                            : AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w600),
                              )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.15)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock, size: 10, color: AppTheme.dangerColor),
                            SizedBox(width: 4),
                            Text('SECURED & LOGGED', style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold, fontSize: 9)),
                          ]),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 12),
            _buildCtrlPaginationControls(totalPages),
          ],
        ],
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: EXPIRY & STOCK ALERTS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildExpiryAlertsTab() {
    final lowStockCol = _buildAlertColumn(
      title: 'Low Stock Medicines',
      icon: Icons.inventory_2_outlined,
      iconColor: AppTheme.dangerColor,
      emptyMsg: 'All stock levels are healthy ✅',
      items: _lowStockItems,
      itemBuilder: (item) {
        final qty = item['quantity'] ?? 0;
        final threshold = item['threshold'] ?? 10;
        final pct = threshold > 0 ? (qty / threshold).clamp(0.0, 1.0) : 0.0;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Text('$qty / $threshold ${item['unit'] ?? ''}',
                style: const TextStyle(fontSize: 11, color: AppTheme.dangerColor, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppTheme.dangerColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                  pct <= 0.25 ? AppTheme.dangerColor : AppTheme.warningColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(item['category'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
        ]);
      },
    );

    final expiringCol = _buildAlertColumn(
      title: 'Expiring Medicines',
      icon: Icons.event_busy_outlined,
      iconColor: AppTheme.warningColor,
      emptyMsg: 'No medicines expiring soon ✅',
      items: _expiringItems,
      itemBuilder: (item) {
        DateTime? exp;
        try { exp = DateTime.parse(item['expiry_date']); } catch (_) {}
        final daysLeft = exp != null ? exp.difference(DateTime.now()).inDays : null;
        final isExpired = (daysLeft ?? 1) < 0;
        final urgencyColor = isExpired
            ? AppTheme.dangerColor
            : (daysLeft ?? 100) <= 7 ? AppTheme.warningColor : AppTheme.textSecondaryColor;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(
                isExpired ? 'EXPIRED' : '${daysLeft}d left',
                style: TextStyle(fontSize: 10, color: urgencyColor, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            exp != null ? 'Expiry: ${DateFormat('dd MMM yyyy').format(exp)}' : 'Unknown expiry',
            style: TextStyle(fontSize: 11, color: urgencyColor),
          ),
          Text('Stock: ${item['quantity'] ?? 0} ${item['unit'] ?? ''} • ${item['category'] ?? ''}',
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
        ]);
      },
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: widget.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                lowStockCol,
                const SizedBox(height: 20),
                expiringCol,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: lowStockCol),
                const SizedBox(width: 20),
                Expanded(child: expiringCol),
              ],
            ),
    );
  }

  Widget _buildAlertColumn({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String emptyMsg,
    required List<dynamic> items,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Row(children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('${items.length}', style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
        ),
        const Divider(height: 1),
        if (items.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey))))
        else
          ...items.map((item) => Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: itemBuilder(item as Map<String, dynamic>),
            ),
            const Divider(height: 1),
          ])),
      ]),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCtrlPaginationControls(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Page ${_ctrlPage + 1} of $totalPages',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: _ctrlPage > 0
                ? () => setState(() => _ctrlPage--)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: _ctrlPage > 0
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.chevron_left, size: 18),
                Text('Prev'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _ctrlPage < totalPages - 1
                ? () => setState(() => _ctrlPage++)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: _ctrlPage < totalPages - 1
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Next'),
                Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data class ────────────────────────────────────────────────────────────────

class _StatCard {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color, this.sub);
}
