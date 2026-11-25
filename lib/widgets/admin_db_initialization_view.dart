import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../config/api_config.dart';
import '../services/token_service.dart';

class AdminDbInitializationView extends StatefulWidget {
  final bool isMobile;

  const AdminDbInitializationView({super.key, this.isMobile = false});

  @override
  State<AdminDbInitializationView> createState() =>
      _AdminDbInitializationViewState();
}

class _AdminDbInitializationViewState extends State<AdminDbInitializationView> {
  bool _isLoadingStatus = false;
  bool _isActionRunning = false;
  Map<String, dynamic>? _dbStatus;
  List<String> _consoleLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchDbStatus();
  }

  Future<void> _fetchDbStatus() async {
    setState(() => _isLoadingStatus = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/admin/db/status');
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          setState(() {
            _dbStatus = data['data'];
            _isLoadingStatus = false;
          });
          return;
        }
      }
      throw Exception('Failed to load database status (${res.statusCode})');
    } catch (e) {
      if (mounted) {
        setState(() {
          _dbStatus = {
            'connected': false,
            'error': e.toString().replaceFirst('Exception: ', ''),
          };
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _runDbInitialize() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.storage_outlined, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Initialize Database Schema?'),
          ],
        ),
        content: const Text(
          'This will execute the DDL schema creation and ensure all required tables '
          'and columns exist in PostgreSQL. It runs safely with "IF NOT EXISTS" and '
          'will not delete any existing data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed with Initialization'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isActionRunning = true;
      _consoleLogs = ['[${DateTime.now().toIso8601String()}] Initiating DB Schema Setup...'];
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/admin/db/initialize');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final logs = data['data']?['logs'] as List? ?? [data['message'] ?? 'Done'];
        setState(() {
          _consoleLogs.addAll(logs.map((l) => l.toString()));
          _consoleLogs.add('🎉 Initialization completed successfully.');
        });
        await _fetchDbStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database schema initialized!'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Initialization failed');
      }
    } catch (e) {
      setState(() {
        _consoleLogs.add('❌ Error: ${e.toString()}');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _runDbSeed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.grain_outlined, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Seed Master Catalogs?'),
          ],
        ),
        content: const Text(
          'This will populate or update the master reference data (Billing Services, '
          'Roles, Permissions, Lab Tests, and IPD Beds) with standard hospital defaults. '
          'Existing appointments, patients, and clinical records are untouched.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Catalogs', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isActionRunning = true;
      _consoleLogs = ['[${DateTime.now().toIso8601String()}] Starting Master Catalogs Seeding...'];
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token ?? await TokenService.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/admin/db/seed');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final logs = data['data']?['logs'] as List? ?? [data['message'] ?? 'Done'];
        setState(() {
          _consoleLogs.addAll(logs.map((l) => l.toString()));
          _consoleLogs.add('🎉 Master catalogs seeded successfully.');
        });
        await _fetchDbStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Master catalogs seeded successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Seeding failed');
      }
    } catch (e) {
      setState(() {
        _consoleLogs.add('❌ Error: ${e.toString()}');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _dbStatus?['connected'] == true;
    final String dbName = _dbStatus?['database']?.toString() ?? 'sri_ponni_db';
    final int totalTables = _dbStatus?['totalTables'] ?? 0;
    final Map<String, dynamic> counts = _dbStatus?['masterCounts'] != null
        ? Map<String, dynamic>.from(_dbStatus!['masterCounts'])
        : {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storage_outlined, color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Database Initialization & Master Controls',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Explicit on-demand schema initialization and master catalogs maintenance',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                tooltip: 'Refresh Status',
                onPressed: _fetchDbStatus,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Connection Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isConnected ? Colors.green.shade200 : Colors.red.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.green : Colors.red).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isConnected ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected ? Icons.check_circle : Icons.error_outline,
                    color: isConnected ? Colors.green : Colors.red,
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
                            isConnected ? 'PostgreSQL Database Connected' : 'Database Disconnected / Not Reachable',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isConnected ? 'ACTIVE' : 'OFFLINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                            ? 'Database: $dbName • Verified Public Tables: $totalTables'
                            : 'Error: ${_dbStatus?['error'] ?? 'Ensure PostgreSQL service is running on port 5432'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Master Catalog Record Counts
          const Text(
            'Master Catalogs Status Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricChip('Billing Services', counts['billing_services'] ?? 0, Icons.payments_outlined, Colors.purple),
              _buildMetricChip('Medicine Catalog', counts['medicine_catalog'] ?? 0, Icons.medication_outlined, Colors.teal),
              _buildMetricChip('IPD Hospital Beds', counts['ipd_beds'] ?? 0, Icons.hotel_outlined, Colors.blue),
              _buildMetricChip('Procedures Master', counts['procedures_master'] ?? 0, Icons.healing_outlined, Colors.indigo),
              _buildMetricChip('Consumables Master', counts['consumables_master'] ?? 0, Icons.home_repair_service_outlined, Colors.deepOrange),
              _buildMetricChip('Carried Kit Items', counts['kit_items_master'] ?? 0, Icons.inventory_outlined, Colors.brown),
              _buildMetricChip('Lab Test Master', counts['lab_test_master'] ?? 0, Icons.biotech_outlined, Colors.cyan),
              _buildMetricChip('Specializations', counts['doctor_specializations'] ?? 0, Icons.medical_services_outlined, Colors.green),
              _buildMetricChip('Districts Master', counts['districts'] ?? 0, Icons.location_city_outlined, Colors.indigo),
              _buildMetricChip('PIN Codes Master', counts['pincodes'] ?? 0, Icons.markunread_mailbox_outlined, Colors.deepPurple),
              _buildMetricChip('Registered Users', counts['users'] ?? 0, Icons.people_outline, Colors.blueGrey),
              _buildMetricChip('Patients Directory', counts['patients'] ?? 0, Icons.sick_outlined, Colors.pink),
            ],
          ),
          const SizedBox(height: 28),

          // Action Triggers
          const Text(
            'Database Maintenance Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.construction_outlined, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Initialize Database Schema',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Executes DDL statements to create all 16+ core tables, foreign keys, and indexes. '
                        'Safe to run at any time; never drops or modifies existing data.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isActionRunning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Run Schema Initialization'),
                        onPressed: _isActionRunning ? null : _runDbInitialize,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.grain_outlined, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Seed Default Master Catalogs',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Populates standard reference catalog data (default billing services, roles, permissions, '
                        'lab tests, and initial hospital beds) on demand from the admin.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isActionRunning
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: const Text('Seed Default Master Catalogs'),
                        onPressed: _isActionRunning ? null : _runDbSeed,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Output Console Log Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Initialization Console Output',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    if (_consoleLogs.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _consoleLogs.clear()),
                        child: const Text('Clear', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ),
                  ],
                ),
                const Divider(color: Color(0xFF334155), height: 16),
                if (_consoleLogs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Ready. Click "Run Schema Initialization" or "Seed Default Master Catalogs" to begin.',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _consoleLogs
                            .map(
                              (log) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: log.startsWith('❌')
                                        ? Colors.redAccent
                                        : log.startsWith('⚠️')
                                            ? Colors.amberAccent
                                            : log.startsWith('✅') || log.startsWith('🎉')
                                                ? Colors.greenAccent
                                                : Colors.white,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String title, int count, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
