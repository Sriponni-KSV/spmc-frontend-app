import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class PharmacyManagementView extends StatefulWidget {
  final bool isMobile;
  const PharmacyManagementView({super.key, this.isMobile = false});

  @override
  State<PharmacyManagementView> createState() => _PharmacyManagementViewState();
}

class _PharmacyManagementViewState extends State<PharmacyManagementView> {
  int _activeTab = 0; // 0 = Prescriptions, 1 = Controlled Drugs
  List<dynamic> _prescriptions = [];
  List<dynamic> _controlledDrugs = [];
  List<dynamic> _inventory = [];
  Map<String, dynamic>? _selectedPrescription;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  String get baseUrl => dotenv.env['BASE_URL']!;

  @override
  void initState() {
    super.initState();
    _loadPharmacyData();
  }

  Future<void> _loadPharmacyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        ApiService.get('$baseUrl/pharmacy/prescriptions'),
        ApiService.get('$baseUrl/pharmacy/controlled-drugs'),
        ApiService.get('$baseUrl/inventory/items'),
      ]);

      final presBody = ApiService.decodeJsonResponse(responses[0]);
      final controlledBody = ApiService.decodeJsonResponse(responses[1]);
      final invBody = ApiService.decodeJsonResponse(responses[2]);

      if (mounted) {
        setState(() {
          _prescriptions = presBody['data'] ?? [];
          _controlledDrugs = controlledBody['data'] ?? [];
          _inventory = invBody['data'] ?? [];
          
          // Select first pending prescription by default if available
          final pending = _prescriptions.where((p) => p['pharmacy_status'] == 'Pending').toList();
          if (pending.isNotEmpty) {
            _selectedPrescription = pending.first;
          } else if (_prescriptions.isNotEmpty) {
            _selectedPrescription = _prescriptions.first;
          }
          
          _isLoading = false;
        });
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

  // Check if item exists in inventory and has sufficient stock
  Map<String, dynamic> _checkItemStock(String name, int neededQty) {
    final match = _inventory.firstWhere(
      (item) => item['name'].toString().toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );
    if (match == null) {
      return {'available': false, 'qty': 0, 'registered': false};
    }
    return {
      'available': match['quantity'] >= neededQty,
      'qty': match['quantity'],
      'registered': true,
    };
  }

  Future<void> _dispensePrescription(Map<String, dynamic> prescription) async {
    final clientItems = prescription['items'] as List<dynamic>;
    
    // Prepare dispense payload items
    final dispenseItems = clientItems.map((item) {
      return {
        'name': item['name'] ?? '',
        'quantity': 10 // Standard pack size dispensed per item line
      };
    }).toList();

    try {
      final response = await ApiService.post(
        '$baseUrl/pharmacy/dispense',
        {
          'id': prescription['id'],
          'type': prescription['type'],
          'items': dispenseItems,
        },
      );
      final body = ApiService.decodeJsonResponse(response);
      if (response.statusCode == 200 && body['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription dispensed successfully!'), backgroundColor: Colors.green),
        );
        _loadPharmacyData();
      } else {
        throw Exception(body['message'] ?? 'Failed to dispense');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispensation failed: $e'), backgroundColor: Colors.red),
      );
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
            Text('Error loading Pharmacy: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPharmacyData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pharmacy Command & Dispensing',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Process doctor prescriptions and track controlled pharmaceuticals',
                    style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _loadPharmacyData,
                tooltip: 'Refresh Pharmacy Queue',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sub tabs toggle
          Row(
            children: [
              _buildTabButton(0, 'Prescriptions Queue', Icons.queue_play_next),
              const SizedBox(width: 12),
              _buildTabButton(1, 'Controlled Drug Inventory', Icons.lock),
            ],
          ),
          const SizedBox(height: 24),

          if (_activeTab == 0) _buildPrescriptionsQueueView() else _buildControlledDrugsView(),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isSelected = _activeTab == index;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primaryColor : Colors.white,
        foregroundColor: isSelected ? Colors.white : AppTheme.textSecondaryColor,
        elevation: 0,
        side: BorderSide(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: () => setState(() => _activeTab = index),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildPrescriptionsQueueView() {
    final filtered = _prescriptions.where((p) {
      final query = _searchQuery.toLowerCase();
      final pName = (p['patient_name'] ?? '').toString().toLowerCase();
      final pId = (p['patient_display_id'] ?? '').toString().toLowerCase();
      return pName.contains(query) || pId.contains(query);
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: List
        Expanded(
          flex: 4,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by Patient Name or ID...',
                  prefixIcon: const Icon(Icons.search),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderColor)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No pending pharmacy orders in queue.', style: TextStyle(color: Colors.grey))),
                  ),
                )
              else
                SizedBox(
                  height: 500,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, idx) {
                      final pres = filtered[idx];
                      final isSelected = _selectedPrescription != null && _selectedPrescription!['id'] == pres['id'] && _selectedPrescription!['type'] == pres['type'];
                      final isDispensed = pres['pharmacy_status'] == 'Dispensed';

                      return Card(
                        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedPrescription = pres),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  pres['type'] == 'outpatient' ? Icons.personal_injury_outlined : Icons.hotel_outlined,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pres['patient_name'] ?? 'Unknown Patient',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: ${pres['patient_display_id'] ?? '--'} • Dr. ${pres['doctor_name'] ?? '--'}',
                                        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDispensed ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isDispensed ? 'DISPENSED' : 'PENDING',
                                    style: TextStyle(
                                      color: isDispensed ? Colors.green : Colors.amber.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
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
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: Detail Pane
        Expanded(
          flex: 5,
          child: _selectedPrescription == null
              ? Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Center(
                    child: Text('Select an order from the list to view details', style: TextStyle(color: Colors.grey)),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order details: ${_selectedPrescription!['patient_name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            (_selectedPrescription!['type'] ?? 'opd').toString().toUpperCase(),
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_selectedPrescription!['created_at']))}',
                        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                      ),
                      const Divider(height: 32),

                      const Text('Prescribed Medications:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),

                      // List of prescribed drugs and stock check
                      ...(_selectedPrescription!['items'] as List<dynamic>).map((item) {
                        final drugName = item['name'] ?? '';
                        final stockCheck = _checkItemStock(drugName, 10); // Check if 10 tablets/units are available
                        
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      drugName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dosage: ${item['dosage'] ?? '--'} • Freq: ${item['frequency'] ?? '--'} • Dur: ${item['duration'] ?? '--'}',
                                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),

                              // Stock badge indicator
                              Row(
                                children: [
                                  Icon(
                                    stockCheck['available'] ? Icons.check_circle : Icons.error_outline,
                                    color: stockCheck['available'] ? Colors.green : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    stockCheck['registered'] 
                                        ? 'In Stock: ${stockCheck['qty']}' 
                                        : 'Not in Inventory',
                                    style: TextStyle(
                                      color: stockCheck['available'] ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 24),

                      // Dispense Button
                      if (_selectedPrescription!['pharmacy_status'] == 'Pending')
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _dispensePrescription(_selectedPrescription!),
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                            label: const Text('Dispense Medications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'This prescription has already been dispensed',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildControlledDrugsView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          columns: const [
            DataColumn(label: Text('Item Name')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Stock Quantity')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Controlled Status')),
          ],
          rows: _controlledDrugs.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(item['category'] ?? '')),
                DataCell(
                  Text(
                    (item['quantity'] ?? 0).toString(),
                    style: TextStyle(
                      color: (item['quantity'] ?? 0) <= (item['threshold'] ?? 10) ? Colors.red : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(Text(item['unit'] ?? '')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SECURED & LOGGED',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
