import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ICUManagementView extends StatefulWidget {
  final bool isMobile;
  const ICUManagementView({super.key, this.isMobile = false});

  @override
  State<ICUManagementView> createState() => _ICUManagementViewState();
}

class _ICUManagementViewState extends State<ICUManagementView> {
  List<dynamic> _alerts = [];
  bool _isLoading = true;
  String? _error;

  String get baseUrl => dotenv.env['BASE_URL']!;

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
      final response = await ApiService.get('$baseUrl/ipd/icu/dashboard');
      final body = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 200 && body['success'] == true) {
        if (mounted) {
          setState(() {
            _alerts = body['data'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception(body['message'] ?? 'Failed to load ICU dashboard');
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

  Future<void> _escalateAlert(int alertId) async {
    final TextEditingController notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escalate Critical Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter escalation instructions or clinical notes for the next tier:'),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Patient status worsening, needs urgent consultant review...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
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
      final response = await ApiService.post(
        '$baseUrl/ipd/icu-alerts/$alertId/escalate',
        {'notes': notesCtrl.text.trim()},
      );
      final body = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 200 && body['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert escalated successfully'), backgroundColor: Colors.green),
        );
        _fetchIcuDashboard();
      } else {
        throw Exception(body['message'] ?? 'Failed to escalate alert');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resolveAlert(int alertId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve ICU Alert'),
        content: const Text('Are you sure you want to mark this critical warning alert as resolved?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.post('$baseUrl/ipd/icu-alerts/$alertId/resolve', {});
      final body = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 200 && body['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert resolved'), backgroundColor: Colors.green),
        );
        _fetchIcuDashboard();
      } else {
        throw Exception(body['message'] ?? 'Failed to resolve alert');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

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

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ICU & Emergency command Centre',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time monitoring of critical patient alerts and escalation levels',
                    style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _fetchIcuDashboard,
                tooltip: 'Refresh Patient Alerts',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats cards
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
                  'Monitored Patients',
                  _alerts.length.toString(),
                  Icons.monitor_heart,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Grid/List of alerts
          if (_alerts.isEmpty)
            Container(
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
                      'All patients vitals are within normal range.',
                      style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.isMobile ? 1 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 340,
              ),
              itemCount: _alerts.length,
              itemBuilder: (ctx, idx) {
                final alert = _alerts[idx];
                final severityColor = _getSeverityColor(alert['severity'] ?? 'Warning');
                final escalationLevel = alert['escalation_level'] ?? 'Nurse';

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
                        // Patient Title / Location
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

                        // Current Escalation Level
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

                        // Vitals summary
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildVitalMiniRow('SPO2', '${alert['spo2'] ?? '--'}%', alert['spo2'] != null && alert['spo2'] < 90),
                            _buildVitalMiniRow('Temp', '${alert['temperature'] ?? '--'}°F', alert['temperature'] != null && alert['temperature'] > 101),
                            _buildVitalMiniRow('Pulse', '${alert['pulse'] ?? '--'} bpm', alert['pulse'] != null && (alert['pulse'] > 120 || alert['pulse'] < 50)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Alert message
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alert['alert_message'] ?? 'Critical Alert Triggered.',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const Spacer(),

                        // Actions Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _resolveAlert(alert['id']),
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
                              onPressed: escalationLevel == 'Consultant' ? null : () => _escalateAlert(alert['id']),
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
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String val, IconData icon, Color color) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
              const SizedBox(height: 4),
              Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            ],
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
