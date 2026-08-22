import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';

class ICUManagementView extends StatefulWidget {
  final bool isMobile;
  const ICUManagementView({super.key, this.isMobile = false});

  @override
  State<ICUManagementView> createState() => _ICUManagementViewState();
}

class _ICUManagementViewState extends State<ICUManagementView> {
  List<dynamic> _alerts = [];
  List<dynamic> _beds = [];
  List<dynamic> _alertHistory = [];
  bool _isLoading = true;
  String? _error;

  String get baseUrl => ApiEndpoints.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchIcuDashboard();
  }

  Future<void> _fetchIcuDashboard() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        ApiService.get('$baseUrl/ipd/icu/dashboard'),
        ApiService.get('$baseUrl/ipd/beds'),
        ApiService.get('$baseUrl/ipd/icu/alerts/history'),
      ]);

      final dashboardBody = ApiService.decodeJsonResponse(responses[0]);
      final bedsBody = ApiService.decodeJsonResponse(responses[1]);
      final historyBody = ApiService.decodeJsonResponse(responses[2]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200 &&
          dashboardBody['success'] == true) {
        if (mounted) {
          setState(() {
            _alerts = dashboardBody['data'] ?? [];
            final List<dynamic> allBeds = bedsBody['data'] ?? [];
            _beds = allBeds.where((b) => b['ward_type'] == 'ICU').toList();
            _alertHistory = historyBody['data'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load ICU dashboard data');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _groupAlertsList(List<dynamic> rawAlerts) {
    final Map<int, Map<String, dynamic>> grouped = {};

    for (final alert in rawAlerts) {
      final int admissionId = alert['admission_id'] ?? 0;
      if (admissionId == 0) continue;

      if (!grouped.containsKey(admissionId)) {
        grouped[admissionId] = {
          'admission_id': admissionId,
          'patient_id': alert['patient_id'],
          'patient_name': alert['patient_name'],
          'patient_age': alert['patient_age'],
          'bed_number': alert['bed_number'],
          'ward_type': alert['ward_type'],
          'doctor_name': alert['doctor_name'],
          'temperature': alert['temperature'],
          'pulse': alert['pulse'],
          'spo2': alert['spo2'],
          'blood_pressure_systolic': alert['blood_pressure_systolic'],
          'blood_pressure_diastolic': alert['blood_pressure_diastolic'],
          'respiratory_rate': alert['respiratory_rate'],
          'alert_ids': [alert['id']],
          'alert_messages': [alert['alert_message']],
          'severities': [alert['severity']],
          'escalation_levels': [alert['escalation_level'] ?? 'Nurse'],
          'raw_alerts': [alert],
        };
      } else {
        final current = grouped[admissionId]!;
        (current['alert_ids'] as List).add(alert['id']);
        (current['alert_messages'] as List).add(alert['alert_message']);
        (current['severities'] as List).add(alert['severity']);
        (current['escalation_levels'] as List).add(alert['escalation_level'] ?? 'Nurse');
        (current['raw_alerts'] as List).add(alert);
      }
    }

    final List<Map<String, dynamic>> result = [];
    grouped.forEach((key, val) {
      final List severities = val['severities'];
      final List escalationLevels = val['escalation_levels'];

      final String overallSeverity = severities.contains('Critical') ? 'Critical' : 'Warning';

      String overallEscalation = 'Nurse';
      if (escalationLevels.contains('Consultant')) {
        overallEscalation = 'Consultant';
      } else if (escalationLevels.contains('Duty Doctor')) {
        overallEscalation = 'Duty Doctor';
      }

      val['severity'] = overallSeverity;
      val['escalation_level'] = overallEscalation;
      result.add(val);
    });

    return result;
  }

  Future<void> _escalateGroupedAlerts(List<dynamic> alertIds) async {
    final TextEditingController notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 60),
        title: const Text('Escalate Critical Alert'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter escalation instructions or clinical notes for the next tier:'),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                minLines: 1,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'e.g., Patient status worsening, needs urgent consultant review...',
                  hintMaxLines: 2,
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Escalate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final alertId in alertIds) {
        await ApiService.post(
          '$baseUrl/ipd/icu-alerts/$alertId/escalate',
          {'notes': notesCtrl.text.trim()},
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert(s) escalated successfully'), backgroundColor: Colors.green),
      );
      _fetchIcuDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resolveGroupedAlerts(List<dynamic> alertIds) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          'Resolve ICU Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 440,
          child: Text(
            'Are you sure you want to mark these ${alertIds.length} alert(s) as resolved?',
            softWrap: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final alertId in alertIds) {
        await ApiService.post('$baseUrl/ipd/icu-alerts/$alertId/resolve', {});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert(s) resolved'), backgroundColor: Colors.green),
      );
      _fetchIcuDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _escalateAlert(int alertId) => _escalateGroupedAlerts([alertId]);
  Future<void> _resolveAlert(int alertId) => _resolveGroupedAlerts([alertId]);

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Color _getEscalationBadgeColor(String level) {
    switch (level.toLowerCase()) {
      case 'consultant':
        return Colors.red.shade700;
      case 'duty doctor':
        return Colors.orange.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading dashboard: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchIcuDashboard, child: const Text('Retry')),
          ],
        ),
      );
    }

    final int criticalCount = _alerts.where((a) => a['severity'] == 'Critical').length;
    final int warningCount = _alerts.where((a) => a['severity'] == 'Warning').length;
    final int occupiedBeds = _beds.where((b) => b['status'] == 'Occupied').length;
    final int totalBeds = _beds.isEmpty ? 5 : _beds.length;
    final double occupancyPercentage = (occupiedBeds / totalBeds) * 100;

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Responsive)
          if (widget.isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'ICU & Emergency',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                      onPressed: _fetchIcuDashboard,
                      tooltip: 'Refresh Command Centre',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time patient monitoring and alerts',
                  style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ICU & Emergency',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time monitoring of critical patient alerts and workflow escalation levels',
                        style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: _fetchIcuDashboard,
                  tooltip: 'Refresh Command Centre',
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Stats Cards (Responsive)
          if (widget.isMobile)
            Column(
              children: [
                _buildSummaryCard(
                  'Active Critical Alerts',
                  criticalCount.toString(),
                  Icons.report_problem,
                  Colors.red,
                ),
                const SizedBox(height: 12),
                _buildSummaryCard(
                  'Active Warnings',
                  warningCount.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildSummaryCard(
                  'ICU Bed Occupancy',
                  '${occupancyPercentage.toStringAsFixed(0)}%',
                  Icons.airline_seat_flat_angled,
                  Colors.teal,
                  subtitle: '$occupiedBeds of $totalBeds Beds Occupied',
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Active Critical Alerts',
                    criticalCount.toString(),
                    Icons.report_problem,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Active Warnings',
                    warningCount.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'ICU Bed Occupancy',
                    '${occupancyPercentage.toStringAsFixed(0)}%',
                    Icons.airline_seat_flat_angled,
                    Colors.teal,
                    subtitle: '$occupiedBeds of $totalBeds Beds Occupied',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Split Layout for alerts and sidebar widgets
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Real-Time ICU & Emergency Alerts',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildAlertsGrid(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildBedGrid(),
                          const SizedBox(height: 20),
                          _buildStatusTimeline(),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Real-Time ICU & Emergency Alerts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAlertsGrid(),
                    const SizedBox(height: 24),
                    _buildBedGrid(),
                    const SizedBox(height: 24),
                    _buildStatusTimeline(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 32),

          // Escalation Hierarchy Panel Widget (Nurse -> Duty Doctor -> Consultant columns)
          _buildEscalationHierarchyWidget(),
        ],
      ),
    );
  }

  Widget _buildAlertsGrid() {
    final groupedAlerts = _groupAlertsList(_alerts);
    if (groupedAlerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
              SizedBox(height: 16),
              Text(
                'No Active Critical ICU Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'All patient vitals are within normal range.',
                style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.isMobile ? 1 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 340,
      ),
      itemCount: groupedAlerts.length,
      itemBuilder: (ctx, idx) {
        final alert = groupedAlerts[idx];
        final severityColor = _getSeverityColor(alert['severity'] ?? 'Warning');
        final escalationLevel = alert['escalation_level'] ?? 'Nurse';

        final double? spo2Val = double.tryParse(alert['spo2']?.toString() ?? '');
        final double? tempVal = double.tryParse(alert['temperature']?.toString() ?? '');
        final double? pulseVal = double.tryParse(alert['pulse']?.toString() ?? '');

        return Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: severityColor.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        alert['patient_name'] ?? 'Unknown Patient',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (alert['severity'] ?? 'Info').toUpperCase(),
                        style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bed ${alert['bed_number'] ?? '--'} • ${alert['ward_type'] ?? 'ICU'} • Age: ${alert['patient_age'] ?? '--'}',
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                ),
                const Divider(height: 24),

                Row(
                  children: [
                    const Text('Escalation Tier: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getEscalationBadgeColor(escalationLevel).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        escalationLevel,
                        style: TextStyle(
                          color: _getEscalationBadgeColor(escalationLevel),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildVitalMiniRow('SPO2', '${alert['spo2'] ?? '--'}%', spo2Val != null && spo2Val < 90),
                    _buildVitalMiniRow('Temp', '${alert['temperature'] ?? '--'}°F', tempVal != null && tempVal > 101),
                    _buildVitalMiniRow('Pulse', '${alert['pulse'] ?? '--'} bpm', pulseVal != null && (pulseVal > 120 || pulseVal < 50)),
                  ],
                ),
                const SizedBox(height: 12),

                // Grouped active alerts list
                Container(
                  width: double.infinity,
                  height: 60,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: (alert['alert_messages'] as List).length,
                    itemBuilder: (context, msgIdx) {
                      final msg = alert['alert_messages'][msgIdx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Expanded(
                              child: Text(
                                msg,
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Spacer(),

                if (widget.isMobile)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _resolveGroupedAlerts(alert['alert_ids']),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 14),
                              SizedBox(width: 4),
                              Text('Resolve', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: escalationLevel == 'Consultant' ? null : () => _escalateGroupedAlerts(alert['alert_ids']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.dangerColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Escalate', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _resolveGroupedAlerts(alert['alert_ids']),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Resolve'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: escalationLevel == 'Consultant' ? null : () => _escalateGroupedAlerts(alert['alert_ids']),
                        icon: const Icon(Icons.arrow_upward, size: 16, color: Colors.white),
                        label: const Text('Escalate Tier', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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

  Widget _buildBedGrid() {
    int occupied = _beds.where((b) => b['status'] != 'Available').length;
    int total = _beds.isEmpty ? 5 : _beds.length;
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bed_outlined, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ICU Bed Tracker',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$occupied / $total Occupied',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_beds.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No ICU beds registered.', style: TextStyle(color: AppTheme.textSecondaryColor)),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.isMobile ? 4 : 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: _beds.length,
                itemBuilder: (context, index) {
                  final bed = _beds[index];
                  final isAvailable = bed['status'] == 'Available';
                  final color = isAvailable ? AppTheme.successColor : AppTheme.dangerColor;
                  return Tooltip(
                    message: 'Bed: ${bed['bed_number']} • Status: ${bed['status']}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        border: Border.all(color: color, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isAvailable ? Icons.king_bed_outlined : Icons.airline_seat_flat_angled,
                            color: color,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bed['bed_number']?.replaceAll('ICU-', '') ?? '',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
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
    );
  }

  Widget _buildStatusTimeline() {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Patient Status Timeline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_alertHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No recent alert history.',
                    style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _alertHistory.length > 5 ? 5 : _alertHistory.length,
                separatorBuilder: (context, index) => const Divider(height: 16, indent: 32),
                itemBuilder: (context, index) {
                  final alert = _alertHistory[index];
                  final isResolved = alert['status'] == 'Resolved';
                  final isEscalated = alert['escalation_level'] != 'Nurse' && alert['escalation_level'] != null;

                  Color color = AppTheme.warningColor;
                  IconData icon = Icons.warning_amber_rounded;

                  if (isResolved) {
                    color = AppTheme.successColor;
                    icon = Icons.check_circle_outline;
                  } else if (alert['severity'] == 'Critical') {
                    color = AppTheme.dangerColor;
                    icon = Icons.error_outline;
                  }

                  if (isEscalated && !isResolved) {
                    icon = Icons.trending_up;
                    color = Colors.purple;
                  }

                  String dateStr = '';
                  try {
                    final date = DateTime.parse(alert['updated_at'] ?? alert['created_at']).toLocal();
                    dateStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                  } catch (e) {
                    dateStr = '--:--';
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  alert['patient_name'] ?? 'Patient',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  dateStr,
                                  style: const TextStyle(color: AppTheme.textMutedColor, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isResolved
                                  ? 'Resolved: ${alert['alert_message']}'
                                  : (isEscalated
                                      ? 'Escalated to ${alert['escalation_level']}: ${alert['alert_message']}'
                                      : 'Active: ${alert['alert_message']}'),
                              style: TextStyle(
                                color: isResolved ? AppTheme.textSecondaryColor : AppTheme.textPrimaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEscalationHierarchyWidget() {
    final groupedAlerts = _groupAlertsList(_alerts);
    final nurseAlerts = groupedAlerts.where((a) => a['escalation_level'] == 'Nurse').toList();
    final doctorAlerts = groupedAlerts.where((a) => a['escalation_level'] == 'Duty Doctor').toList();
    final consultantAlerts = groupedAlerts.where((a) => a['escalation_level'] == 'Consultant').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Automated Escalation Workflow Hierarchy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        const Text(
          'Track patient alerts routed through the staff responsibility tiers',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildHierarchyColumn(
                      'Level 1: Nurse Tier',
                      nurseAlerts,
                      Colors.amber,
                      Icons.person_outline,
                      'Assesses alert, titrates oxygen, updates vitals. If unresolved in 10m, escalates.',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHierarchyColumn(
                      'Level 2: Duty Doctor',
                      doctorAlerts,
                      Colors.orange,
                      Icons.medical_services_outlined,
                      'Evaluates clinical status, writes immediate orders, runs labs, adjusts meds.',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHierarchyColumn(
                      'Level 3: Consultant',
                      consultantAlerts,
                      Colors.red,
                      Icons.workspace_premium_outlined,
                      'Final clinical decision, critical interventions, surgical orders, discharge approvals.',
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildHierarchyColumn(
                    'Level 1: Nurse Tier',
                    nurseAlerts,
                    Colors.amber,
                    Icons.person_outline,
                    'Assesses alert, titrates oxygen, updates vitals. If unresolved, escalates.',
                  ),
                  const SizedBox(height: 16),
                  _buildHierarchyColumn(
                    'Level 2: Duty Doctor',
                    doctorAlerts,
                    Colors.orange,
                    Icons.medical_services_outlined,
                    'Evaluates clinical status, writes immediate orders, adjusts meds.',
                  ),
                  const SizedBox(height: 16),
                  _buildHierarchyColumn(
                    'Level 3: Consultant',
                    consultantAlerts,
                    Colors.red,
                    Icons.workspace_premium_outlined,
                    'Final clinical decision, critical interventions, discharge approvals.',
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildHierarchyColumn(
    String title,
    List<dynamic> alerts,
    Color tierColor,
    IconData tierIcon,
    String protocolText,
  ) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tierColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tierIcon, color: tierColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${alerts.length} Patients',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              protocolText,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic),
            ),
            const Divider(height: 20),
            if (alerts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Clear. No active cases.',
                    style: TextStyle(color: AppTheme.textMutedColor, fontSize: 12),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  final double? tempVal = double.tryParse(alert['temperature']?.toString() ?? '');
                  final double? spo2Val = double.tryParse(alert['spo2']?.toString() ?? '');
                  final double? pulseVal = double.tryParse(alert['pulse']?.toString() ?? '');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              alert['patient_name'] ?? 'Patient',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              'Bed ${alert['bed_number'] ?? '--'}',
                              style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Show all alert messages
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: (alert['alert_messages'] as List).map((msg) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                '• $msg',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildVitalMiniIndicator('SPO2', '${alert['spo2'] ?? '--'}%', spo2Val != null && spo2Val < 90),
                            _buildVitalMiniIndicator('Temp', '${alert['temperature'] ?? '--'}°F', tempVal != null && tempVal > 101),
                            _buildVitalMiniIndicator('Pulse', '${alert['pulse'] ?? '--'} bpm', pulseVal != null && (pulseVal > 120 || pulseVal < 50)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => _resolveGroupedAlerts(alert['alert_ids']),
                              child: const Row(
                                children: [
                                  Icon(Icons.check, color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text('Resolve', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            if (alert['escalation_level'] != 'Consultant')
                              GestureDetector(
                                onTap: () => _escalateGroupedAlerts(alert['alert_ids']),
                                child: const Row(
                                  children: [
                                    Icon(Icons.arrow_upward, color: Colors.purple, size: 14),
                                    SizedBox(width: 4),
                                    Text('Escalate', style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildVitalMiniIndicator(String label, String val, bool isCritical) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMutedColor, fontSize: 9)),
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: isCritical ? Colors.red : AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String val, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
                const SizedBox(height: 4),
                Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalMiniRow(String label, String value, bool isCritical) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isCritical ? Colors.red : Colors.black,
          ),
        ),
      ],
    );
  }
}
