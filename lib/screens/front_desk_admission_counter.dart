import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/ipd_controller.dart';
import '../widgets/custom_dropdown_search.dart';

class FrontDeskAdmissionCounterView extends StatefulWidget {
  const FrontDeskAdmissionCounterView({Key? key}) : super(key: key);

  @override
  State<FrontDeskAdmissionCounterView> createState() =>
      _FrontDeskAdmissionCounterViewState();
}

class _FrontDeskAdmissionCounterViewState
    extends State<FrontDeskAdmissionCounterView> {
  final IpdController _ipdController = IpdController();

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _beds = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _ipdController.fetchPendingRequests();
      final bedsData = await _ipdController.fetchBeds();
      if (mounted) {
        setState(() {
          _pendingRequests = data;
          _beds = bedsData;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final totalBeds = _beds.length;
    final availableBeds = _beds.where((b) => b['status'] == 'Available').length;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 24, isMobile ? 16 : 24, 0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admission Counter',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review and process pending IPD admission requests',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _fetchRequests,
                          icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                          label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                          style: AppTheme.primaryButton,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admission Counter',
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review and process pending IPD admission requests',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _fetchRequests,
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                        label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                        style: AppTheme.primaryButton,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // Stats Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: _buildStatsRow(isMobile),
          ),
          const SizedBox(height: 24),

          // TabBar
          Container(
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              isScrollable: isMobile,
              tabAlignment: isMobile ? TabAlignment.start : null,
              tabs: [
                Tab(text: 'Pending Requests (${_pendingRequests.length})'),
                Tab(text: 'Bed Availability ($availableBeds/$totalBeds)'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Pending Requests
                ListView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  children: [
                    _buildRequestsList(isMobile),
                  ],
                ),
                // Tab 2: Bed Availability
                _buildBedAvailabilityTab(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 195,
              child: _buildStatCard(
                'Pending',
                _pendingRequests.length.toString(),
                'Awaiting processing',
                Icons.pending_actions_outlined,
                const Color(0xFFE67E22),
                isMobile,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 195,
              child: _buildStatCard(
                'Today',
                _pendingRequests
                    .where((r) {
                      final d = r['requested_at']?.toString() ?? '';
                      return d.startsWith(DateTime.now().toIso8601String().substring(0, 10));
                    })
                    .length
                    .toString(),
                'Requests today',
                Icons.today_outlined,
                const Color(0xFF2980B9),
                isMobile,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 195,
              child: _buildStatCard(
                'ICU Requests',
                _pendingRequests
                    .where((r) =>
                        r['bed_type_requirement']?.toString().toUpperCase() == 'ICU')
                    .length
                    .toString(),
                'High priority',
                Icons.monitor_heart_outlined,
                const Color(0xFFC0392B),
                isMobile,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending',
            _pendingRequests.length.toString(),
            'Awaiting processing',
            Icons.pending_actions_outlined,
            const Color(0xFFE67E22),
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Today',
            _pendingRequests
                .where((r) {
                  final d = r['requested_at']?.toString() ?? '';
                  return d.startsWith(DateTime.now().toIso8601String().substring(0, 10));
                })
                .length
                .toString(),
            'Requests today',
            Icons.today_outlined,
            const Color(0xFF2980B9),
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'ICU Requests',
            _pendingRequests
                .where((r) =>
                    r['bed_type_requirement']?.toString().toUpperCase() == 'ICU')
                .length
                .toString(),
            'High priority',
            Icons.monitor_heart_outlined,
            const Color(0xFFC0392B),
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: isMobile ? 12 : 14),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.textSecondaryColor, fontSize: isMobile ? 10 : 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.list_alt_outlined,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pending Admission Requests',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                        color: AppTheme.textPrimaryColor),
                  ),
                ),
                if (_pendingRequests.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE67E22).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pendingRequests.length} pending',
                      style: const TextStyle(
                          color: Color(0xFFE67E22),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade400, size: 40),
                    const SizedBox(height: 12),
                    Text('Error: $_error',
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchRequests,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_pendingRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_outline,
                          color: Colors.green.shade400, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No pending admission requests',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'All admission requests have been processed',
                      style: TextStyle(
                          color: AppTheme.textSecondaryColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_pendingRequests.length, (i) {
              final req = _pendingRequests[i];
              return _buildRequestCard(req, i, isMobile);
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
      Map<String, dynamic> req, int index, bool isMobile) {
    String timeAgo = '';
    try {
      final requested = DateTime.parse(req['requested_at'] ?? '');
      final diff = DateTime.now().difference(requested);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = DateFormat('dd MMM').format(requested);
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Patient info + time
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    (req['patient_name']?.toString() ?? 'P')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['patient_name']?.toString() ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${req['patient_display_id'] ?? ''} • ${req['patient_gender'] ?? ''} • ${req['patient_age'] ?? ''}y',
                        style: const TextStyle(
                            color: AppTheme.textSecondaryColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: const TextStyle(
                      color: AppTheme.textSecondaryColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(Icons.person_outline,
                    'Dr. ${req['doctor_name'] ?? '-'}', Colors.indigo),
                if ((req['patient_phone'] ?? '').toString().isNotEmpty)
                  _infoChip(
                      Icons.phone_outlined,
                      req['patient_phone'].toString(),
                      Colors.green),
              ],
            ),

            if ((req['diagnosis'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.medical_information_outlined,
                        size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diagnosis: ${req['diagnosis']}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if ((req['reason_for_admission'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_outlined,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req['reason_for_admission'].toString(),
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),

            // Action button
            isMobile
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showProcessDialog(req),
                      icon: const Icon(Icons.assignment_turned_in_outlined,
                          size: 16, color: Colors.white),
                      label: const Text('Process Admission',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showProcessDialog(req),
                        icon: const Icon(Icons.assignment_turned_in_outlined,
                            size: 16, color: Colors.white),
                        label: const Text('Process Admission',
                            style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: const Size(0, 38),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showProcessDialog(Map<String, dynamic> req) {
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    bool documentsVerified = false;

    // Bed selection fields
    String? selectedWardType = req['bed_type_requirement'];
    if (selectedWardType != null && selectedWardType.trim().isNotEmpty) {
      const allowedWards = ['General', 'Semi-Private', 'Private', 'ICU'];
      final trimmed = selectedWardType.trim();
      if (!allowedWards.contains(trimmed)) {
        final match = allowedWards.firstWhere(
          (w) => w.toLowerCase() == trimmed.toLowerCase(),
          orElse: () => '',
        );
        selectedWardType = match.isNotEmpty ? match : null;
      } else {
        selectedWardType = trimmed;
      }
    } else {
      selectedWardType = null;
    }

    String? selectedBedNumber;
    List<String> availableBeds = selectedWardType == null
        ? []
        : _beds
            .where((b) => b['ward_type'] == selectedWardType && b['status'] == 'Available')
            .map((b) => b['bed_number'].toString())
            .toList();

    // Insurance fields
    final TextEditingController insuranceProviderController =
        TextEditingController();
    final TextEditingController insurancePolicyNoController =
        TextEditingController();
    final TextEditingController advancePaymentController =
        TextEditingController();

    // Document checklist
    final Map<String, bool> docChecklist = {
      'Referral Letter / Doctor Note': false,
      'Insurance Card / Policy Document': false,
      'ID Proof (Aadhar / Passport)': false,
      'Previous Medical Records': false,
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) {
          void updateBedsForWard(String? ward) {
            setD(() {
              selectedWardType = ward;
              selectedBedNumber = null;
              if (ward != null) {
                availableBeds = _beds
                    .where((b) => b['ward_type'] == ward && b['status'] == 'Available')
                    .map((b) => b['bed_number'].toString())
                    .toList();
              } else {
                availableBeds = [];
              }
            });
          }

          final double screenWidth = MediaQuery.of(ctx).size.width;
          final bool isMobileWidth = screenWidth < 600;
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: isMobileWidth ? screenWidth * 0.95 : 560,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Process Admission',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              Text(
                                req['patient_name']?.toString() ?? '',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Patient Summary
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  _summaryRow('Patient',
                                      req['patient_name']?.toString() ?? '-'),
                                  _summaryRow('Doctor',
                                      'Dr. ${req['doctor_name'] ?? '-'}'),
                                  _summaryRow('Diagnosis',
                                      req['diagnosis']?.toString() ?? '-'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Bed Allocation
                            const Text('Bed Allocation',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimaryColor)),
                            const SizedBox(height: 10),
                             CustomDropdownSearch(
                               label: 'Ward Type',
                               hint: 'Select Ward Type',
                               value: selectedWardType,
                               dropdownMap: const {
                                 'General': 'General Ward',
                                 'Semi-Private': 'Semi-Private Ward',
                                 'Private': 'Private Ward',
                                 'ICU': 'ICU',
                               },
                               onChanged: (val) {
                                 updateBedsForWard(val);
                               },
                               validator: (val) => val == null || val.isEmpty ? 'Please select a ward type' : null,
                             ),
                             const SizedBox(height: 16),
                             CustomDropdownSearch(
                               label: 'Available Beds',
                               hint: 'Select Bed',
                               value: selectedBedNumber,
                               dropdownMap: {
                                 for (var bed in availableBeds)
                                   bed: 'Bed $bed',
                               },
                               onChanged: (val) {
                                 setD(() => selectedBedNumber = val);
                               },
                               validator: (val) => val == null || val.isEmpty ? 'Please select a bed' : null,
                             ),
                             const SizedBox(height: 20),

                            // Documents Checklist
                            const Text('Documents Verification',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimaryColor)),
                            const SizedBox(height: 10),
                            ...docChecklist.keys.map((doc) {
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                title: Text(doc,
                                    style: const TextStyle(fontSize: 13)),
                                value: docChecklist[doc],
                                activeColor: AppTheme.primaryColor,
                                onChanged: (v) {
                                  setD(() => docChecklist[doc] = v ?? false);
                                  setD(() => documentsVerified =
                                      docChecklist.values.every((v) => v));
                                },
                              );
                            }).toList(),
                            const SizedBox(height: 16),

                            // Insurance Details
                            const Text('Insurance Details (Optional)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimaryColor)),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: insuranceProviderController,
                              maxLength: 50,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                              ],
                              decoration: _fieldDecoration(
                                  'Insurance Provider',
                                  Icons.health_and_safety_outlined),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: insurancePolicyNoController,
                              maxLength: 50,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9\-/]')),
                              ],
                              decoration: _fieldDecoration(
                                  'Policy Number', Icons.numbers_outlined),
                            ),
                            const SizedBox(height: 16),

                            // Advance Payment
                            const Text('Advance Payment',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimaryColor)),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: advancePaymentController,
                              maxLength: 10,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                              decoration: _fieldDecoration(
                                  'Amount collected (₹)',
                                  Icons.currency_rupee_outlined),
                            ),
                            const SizedBox(height: 16),

                            // Docs verified indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: documentsVerified
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: documentsVerified
                                        ? Colors.green.shade200
                                        : Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    documentsVerified
                                        ? Icons.check_circle_outline
                                        : Icons.info_outline,
                                    color: documentsVerified
                                        ? Colors.green
                                        : Colors.orange.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      documentsVerified
                                          ? 'All documents verified ✓'
                                          : 'Check all documents to mark verification complete',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: documentsVerified
                                              ? Colors.green.shade700
                                              : Colors.orange.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: isMobileWidth
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              StatefulBuilder(
                                builder: (ctx2, setBtn) => ElevatedButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!.validate()) {
                                            return;
                                          }
                                          setBtn(() => isSubmitting = true);
                                          // Capture context-dependent objects before async gap
                                          final nav = Navigator.of(ctx);
                                          final messenger = ScaffoldMessenger.of(context);
                                          try {
                                            final insuranceDetails = {
                                              'provider': insuranceProviderController.text.trim(),
                                              'policy_no': insurancePolicyNoController.text.trim(),
                                            };
                                            await _ipdController.createAdmissionRecord({
                                              'patient_id': req['patient_id'],
                                              'appointment_id': req['appointment_id'],
                                              'doctor_name': req['doctor_name'],
                                              'diagnosis': req['diagnosis'],
                                              'bed_type_requirement': selectedWardType,
                                              'reason_for_admission': req['reason_for_admission'],
                                              'bed_number': selectedBedNumber,
                                              'insurance_details':
                                                  (insuranceDetails['provider']?.isNotEmpty ?? false)
                                                      ? insuranceDetails
                                                      : null,
                                              'documents_verified': documentsVerified,
                                              'advance_payment': advancePaymentController
                                                      .text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? double.tryParse(
                                                      advancePaymentController.text.trim())
                                                  : null,
                                            });
                                            nav.pop();
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Admission record created and bed allocated successfully!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            if (mounted) _fetchRequests();
                                          } catch (e) {
                                            setBtn(() => isSubmitting = false);
                                            messenger.showSnackBar(SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ));
                                          }
                                        },
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.check_outlined,
                                          size: 16, color: Colors.white),
                                  label: Text(
                                    isSubmitting
                                        ? 'Processing...'
                                        : 'Confirm & Create Record',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    minimumSize: const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: AppTheme.cancelButton.copyWith(
                                  minimumSize: WidgetStateProperty.all(
                                      const Size(double.infinity, 44)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: AppTheme.cancelButton,
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              StatefulBuilder(
                                builder: (ctx2, setBtn) => ElevatedButton.icon(
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!.validate()) {
                                            return;
                                          }
                                          setBtn(() => isSubmitting = true);
                                          // Capture context-dependent objects before async gap
                                          final nav = Navigator.of(ctx);
                                          final messenger = ScaffoldMessenger.of(context);
                                          try {
                                            final insuranceDetails = {
                                              'provider': insuranceProviderController.text.trim(),
                                              'policy_no': insurancePolicyNoController.text.trim(),
                                            };
                                            await _ipdController.createAdmissionRecord({
                                              'patient_id': req['patient_id'],
                                              'appointment_id': req['appointment_id'],
                                              'doctor_name': req['doctor_name'],
                                              'diagnosis': req['diagnosis'],
                                              'bed_type_requirement': selectedWardType,
                                              'reason_for_admission': req['reason_for_admission'],
                                              'bed_number': selectedBedNumber,
                                              'insurance_details':
                                                  (insuranceDetails['provider']?.isNotEmpty ?? false)
                                                      ? insuranceDetails
                                                      : null,
                                              'documents_verified': documentsVerified,
                                              'advance_payment': advancePaymentController
                                                      .text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? double.tryParse(
                                                      advancePaymentController.text.trim())
                                                  : null,
                                            });
                                            nav.pop();
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Admission record created and bed allocated successfully!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            if (mounted) _fetchRequests();
                                          } catch (e) {
                                            setBtn(() => isSubmitting = false);
                                            messenger.showSnackBar(SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ));
                                          }
                                        },
                                  icon: isSubmitting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.check_outlined,
                                          size: 16, color: Colors.white),
                                  label: Text(
                                    isSubmitting
                                        ? 'Processing...'
                                        : 'Confirm & Create Record',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    minimumSize: const Size(0, 44),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.textPrimaryColor)),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: Icon(icon, size: 18, color: AppTheme.iconColor),
      filled: true,
      fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildBedAvailabilityTab(bool isMobile) {
    final Map<String, List<Map<String, dynamic>>> groupedBeds = {};
    final wardOrder = ['General', 'Semi-Private', 'Private', 'ICU'];

    for (var ward in wardOrder) {
      groupedBeds[ward] = [];
    }

    for (var bed in _beds) {
      final ward = bed['ward_type'] ?? 'Other';
      groupedBeds.putIfAbsent(ward, () => []).add(bed);
    }

    groupedBeds.removeWhere((key, value) => value.isEmpty);

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      children: groupedBeds.entries.map((entry) {
        final wardName = entry.key;
        final wardBeds = entry.value;

        final totalBeds = wardBeds.length;
        final availableBeds = wardBeds
            .where((b) => b['status'] == 'Available')
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 16),
              child: Row(
                children: [
                  Icon(
                    wardName == 'ICU' ? Icons.local_hospital : Icons.king_bed,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$wardName Ward',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$availableBeds / $totalBeds Available',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: wardBeds.length,
              itemBuilder: (context, index) {
                final bed = wardBeds[index];
                final bool isAvail = bed['status'] == 'Available';
                final Color cardColor = isAvail
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE);
                final Color borderColor = isAvail
                    ? const Color(0xFF81C784)
                    : const Color(0xFFE57373);
                final Color textColor = isAvail
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828);

                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bed['bed_number'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Icon(
                            Icons.king_bed_outlined,
                            color: textColor.withOpacity(0.7),
                            size: 16,
                          ),
                        ],
                      ),
                      Text(
                        isAvail ? 'Available' : 'Occupied',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
          ],
        );
      }).toList(),
    );
  }
}
