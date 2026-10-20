import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';

/// Clinical IPD Medication Administration Record (eMAR) Widget
class IpdMarWidget extends StatefulWidget {
  final Map<String, dynamic> admission;
  final List<Map<String, dynamic>> prescriptions;
  final List<Map<String, dynamic>> medicationLogs;
  final String currentNurseName;
  final bool isMobile;
  final Function({
    required int prescriptionId,
    required String status,
    required String remarks,
    String? administeredAt,
  }) onAdministerDose;
  final VoidCallback? onRefresh;

  const IpdMarWidget({
    super.key,
    required this.admission,
    required this.prescriptions,
    required this.medicationLogs,
    required this.currentNurseName,
    required this.onAdministerDose,
    this.isMobile = false,
    this.onRefresh,
  });

  @override
  State<IpdMarWidget> createState() => _IpdMarWidgetState();
}

enum MarViewTab { matrix, history }

class _IpdMarWidgetState extends State<IpdMarWidget> {
  MarViewTab _currentTab = MarViewTab.matrix;
  DateTime _selectedDate = DateTime.now();
  String _historyFilter = 'All'; // 'All', 'Given', 'Omitted', 'Refused'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _activePrescriptions {
    return widget.prescriptions.where((p) {
      final status = (p['status'] ?? 'Active').toString().toLowerCase();
      final name = (p['medicine_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();
      return status == 'active' && (q.isEmpty || name.contains(q));
    }).toList();
  }

  // Hospital standard shifts & dose time slots
  List<Map<String, String>> get _timeSlots {
    return [
      {'key': '08:00', 'label': 'Morning (08:00)', 'shift': 'Day'},
      {'key': '14:00', 'label': 'Afternoon (14:00)', 'shift': 'Day'},
      {'key': '20:00', 'label': 'Evening (20:00)', 'shift': 'Night'},
      {'key': '02:00', 'label': 'Night (02:00)', 'shift': 'Night'},
    ];
  }

  /// Evaluates which time slots are scheduled based on frequency
  bool _isSlotScheduled(String frequency, String slotKey) {
    final f = frequency.toUpperCase().trim();
    if (f.contains('STAT') || f.contains('PRN') || f.contains('SOS')) {
      return true; // Available on demand
    }
    if (f.contains('QID') || f.contains('4 TIMES') || f.contains('1-1-1-1')) {
      return true; // All 4 slots
    }
    if (f.contains('TID') || f.contains('3 TIMES') || f.contains('1-1-1')) {
      return slotKey == '08:00' || slotKey == '14:00' || slotKey == '20:00';
    }
    if (f.contains('BD') || f.contains('BID') || f.contains('2 TIMES') || f.contains('1-0-1')) {
      return slotKey == '08:00' || slotKey == '20:00';
    }
    if (f.contains('OD') || f.contains('ONCE') || f.contains('1-0-0')) {
      return slotKey == '08:00';
    }
    if (f.contains('0-0-1') || f.contains('NIGHT')) {
      return slotKey == '20:00';
    }
    // Default fallback
    return slotKey == '08:00' || slotKey == '20:00';
  }

  /// Strips internal system slot tag like [Slot:08:00] for clean UI display
  String _cleanRemarks(String rawRemarks) {
    return rawRemarks.replaceAll(RegExp(r'\[Slot:[^\]]+\]\s*'), '').trim();
  }

  /// Finds existing dose log for a prescription on the selected date and shift
  Map<String, dynamic>? _findDoseLog(int prescriptionId, String slotKey) {
    // 1. First priority: explicit slot tag match in remarks (100% precision)
    for (final log in widget.medicationLogs) {
      if (log['prescription_id'] != prescriptionId) continue;
      final rawDate = log['administered_at'] ?? log['created_at'];
      if (rawDate == null) continue;
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        final isSameDate = dt.year == _selectedDate.year &&
            dt.month == _selectedDate.month &&
            dt.day == _selectedDate.day;

        if (!isSameDate) continue;

        final remarks = (log['remarks'] ?? '').toString();
        if (remarks.contains('[Slot:$slotKey]')) {
          return log;
        }
      } catch (_) {}
    }

    // 2. Second priority (fallback for legacy/untagged logs): distinct non-overlapping shift windows
    for (final log in widget.medicationLogs) {
      if (log['prescription_id'] != prescriptionId) continue;
      final rawDate = log['administered_at'] ?? log['created_at'];
      if (rawDate == null) continue;
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        final isSameDate = dt.year == _selectedDate.year &&
            dt.month == _selectedDate.month &&
            dt.day == _selectedDate.day;

        if (!isSameDate) continue;

        final remarks = (log['remarks'] ?? '').toString();
        // If explicitly tagged for a DIFFERENT slot, never match this slot!
        if (remarks.contains('[Slot:') && !remarks.contains('[Slot:$slotKey]')) {
          continue;
        }

        // Distinct, non-overlapping shift windows:
        // Morning (08:00): 05:00 - 11:59
        // Afternoon (14:00): 12:00 - 16:59
        // Evening (20:00): 17:00 - 22:59
        // Night (02:00): 23:00 - 04:59
        final hour = dt.hour;
        String? matchingSlot;
        if (hour >= 5 && hour < 12) {
          matchingSlot = '08:00';
        } else if (hour >= 12 && hour < 17) {
          matchingSlot = '14:00';
        } else if (hour >= 17 && hour < 23) {
          matchingSlot = '20:00';
        } else {
          matchingSlot = '02:00';
        }

        if (matchingSlot == slotKey) {
          return log;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activePrescriptions = _activePrescriptions;
    final totalPrescriptions = activePrescriptions.length;
    final givenToday = widget.medicationLogs.where((l) {
      final s = (l['status'] ?? '').toString().toLowerCase();
      final rawDate = l['administered_at'] ?? l['created_at'];
      if (s != 'given' || rawDate == null) return false;
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        return dt.year == _selectedDate.year &&
            dt.month == _selectedDate.month &&
            dt.day == _selectedDate.day;
      } catch (_) {
        return false;
      }
    }).length;

    final deviationsToday = widget.medicationLogs.where((l) {
      final s = (l['status'] ?? '').toString().toLowerCase();
      final rawDate = l['administered_at'] ?? l['created_at'];
      if ((s != 'omitted' && s != 'missed' && s != 'refused' && s != 'delayed') || rawDate == null) return false;
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        return dt.year == _selectedDate.year &&
            dt.month == _selectedDate.month &&
            dt.day == _selectedDate.day;
      } catch (_) {
        return false;
      }
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Top eMAR KPI & Navigation Header ─────────────────────────────
        _buildTopHeader(totalPrescriptions, givenToday, deviationsToday),
        const SizedBox(height: 16),

        // ─── Content Body (Matrix vs History) ─────────────────────────────
        if (_currentTab == MarViewTab.matrix)
          _buildMarScheduleMatrix(activePrescriptions)
        else
          _buildAuditHistoryTab(),
      ],
    );
  }

  // ─── Top Header Bar ──────────────────────────────────────────────────────

  Widget _buildTopHeader(int totalPresc, int given, int deviations) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
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
                child: const Icon(Icons.medication_liquid_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('emar_title', fallback: 'Inpatient Medication Administration Record (eMAR)'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Signed Nurse: ${widget.currentNurseName} • 5 Rights Verification Active',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              if (widget.onRefresh != null)
                IconButton(
                  tooltip: 'Refresh MAR',
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: widget.onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Date Selector & View Switcher
          widget.isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateSelector(isToday, dateStr),
                    const SizedBox(height: 10),
                    _buildTabSwitcher(),
                  ],
                )
              : Row(
                  children: [
                    _buildDateSelector(isToday, dateStr),
                    const Spacer(),
                    _buildTabSwitcher(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(bool isToday, String dateStr) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            });
          },
        ),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 60)),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                ),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
            });
          },
        ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBtn(MarViewTab.matrix, 'Schedule Matrix', Icons.grid_on_rounded),
          _buildTabBtn(MarViewTab.history, 'Audit & History Log', Icons.history_rounded),
        ],
      ),
    );
  }

  Widget _buildTabBtn(MarViewTab tab, String label, IconData icon) {
    final isSelected = _currentTab == tab;
    return InkWell(
      onTap: () => setState(() => _currentTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MAR Schedule Matrix ─────────────────────────────────────────────────

  Widget _buildMarScheduleMatrix(List<Map<String, dynamic>> prescriptions) {
    if (prescriptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.medication_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'No active inpatient prescriptions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
            ),
            const SizedBox(height: 4),
            const Text(
              'Physician prescriptions will appear here formatted into scheduled administration slots.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search / Filter Row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Filter medications...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Legend
                  Row(
                    children: [
                      _buildMatrixLegendBadge('Given', const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildMatrixLegendBadge('Scheduled', const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      _buildMatrixLegendBadge('Omitted', const Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      _buildMatrixLegendBadge('Refused', const Color(0xFF8B5CF6)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Schedule Matrix Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                dataRowMinHeight: 70,
                dataRowMaxHeight: 85,
                columnSpacing: 20,
                columns: [
                  const DataColumn(
                    label: Text(
                      'Medication & Orders',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  ..._timeSlots.map((slot) {
                    return DataColumn(
                      label: Text(
                        slot['label']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    );
                  }),
                ],
                rows: prescriptions.map((p) {
                  final String medName = p['medicine_name'] ?? '--';
                  final String dosage = p['dosage'] ?? '--';
                  final String freq = p['frequency'] ?? '--';
                  final String route = p['route'] ?? '--';
                  final String instructions = p['instructions'] ?? '';
                  final int prescId = p['id'];

                  return DataRow(
                    cells: [
                      // Drug Detail Cell
                      DataCell(
                        Container(
                          width: 240,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                medName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$dosage • $route • $freq',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                              if (instructions.isNotEmpty)
                                Text(
                                  instructions,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Time Slot Cells
                      ..._timeSlots.map((slot) {
                        final slotKey = slot['key']!;
                        final isScheduled = _isSlotScheduled(freq, slotKey);
                        final existingLog = _findDoseLog(prescId, slotKey);

                        return DataCell(
                          _buildDoseCell(
                            prescription: p,
                            slotKey: slotKey,
                            isScheduled: isScheduled,
                            existingLog: existingLog,
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixLegendBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ─── Dose Cell Inside Matrix ─────────────────────────────────────────────

  Widget _buildDoseCell({
    required Map<String, dynamic> prescription,
    required String slotKey,
    required bool isScheduled,
    required Map<String, dynamic>? existingLog,
  }) {
    if (!isScheduled && existingLog == null) {
      return Container(
        width: 130,
        alignment: Alignment.center,
        child: Text('--', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      );
    }

    if (existingLog != null) {
      final status = (existingLog['status'] ?? 'Given').toString();
      final nurseName = (existingLog['nurse_name'] ?? 'Nurse').toString();
      final rawRemarks = (existingLog['remarks'] ?? '').toString();
      final remarks = _cleanRemarks(rawRemarks);

      Color badgeBg;
      Color badgeBorder;
      Color textColor;
      IconData icon;

      switch (status.toLowerCase()) {
        case 'given':
          badgeBg = const Color(0xFFECFDF5);
          badgeBorder = const Color(0xFFA7F3D0);
          textColor = const Color(0xFF059669);
          icon = Icons.check_circle_rounded;
          break;
        case 'refused':
          badgeBg = const Color(0xFFF5F3FF);
          badgeBorder = const Color(0xFFDDD6FE);
          textColor = const Color(0xFF7C3AED);
          icon = Icons.cancel_outlined;
          break;
        case 'omitted':
        case 'missed':
        default:
          badgeBg = const Color(0xFFFEF2F2);
          badgeBorder = const Color(0xFFFECACA);
          textColor = const Color(0xFFDC2626);
          icon = Icons.warning_amber_rounded;
          break;
      }

      return Tooltip(
        message: '$status by $nurseName\n${remarks.isNotEmpty ? 'Remarks: $remarks' : ''}',
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: badgeBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'By $nurseName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.85)),
              ),
              if (remarks.isNotEmpty)
                Text(
                  remarks,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: textColor.withValues(alpha: 0.75), fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      );
    }

    // Pending / Scheduled Action Buttons
    return SizedBox(
      width: 140,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 13),
              label: const Text('Give Dose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              onPressed: () => _showNurseSignOffModal(prescription, slotKey),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 24,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.shade300),
                foregroundColor: Colors.orange.shade800,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _showOmissionRefusalModal(prescription, slotKey),
              child: const Text('Omit / Refusal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Nurse Sign-Off Modal (5 Rights Verification) ─────────────────────────

  void _showNurseSignOffModal(Map<String, dynamic> prescription, String slotKey) {
    final remarksController = TextEditingController();
    bool confirmedRights = false;
    final patientName = (widget.admission['patient_name'] ?? 'Patient').toString();
    final medName = (prescription['medicine_name'] ?? '--').toString();
    final dosage = (prescription['dosage'] ?? '--').toString();
    final route = (prescription['route'] ?? '--').toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Nurse Medication Administration Sign-Off',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Prescription Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(medName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildMiniDetailBadge('Dose', dosage),
                              const SizedBox(width: 8),
                              _buildMiniDetailBadge('Route', route),
                              const SizedBox(width: 8),
                              _buildMiniDetailBadge('Time Slot', slotKey),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Patient: $patientName', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5 Rights Clinical Verification Checkbox
                    InkWell(
                      onTap: () {
                        setModalState(() => confirmedRights = !confirmedRights);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: confirmedRights ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: confirmedRights ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: confirmedRights,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setModalState(() => confirmedRights = val ?? false);
                              },
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'I verify the 5 Rights: Right Patient, Right Drug, Right Dose, Right Route, and Right Time before administering.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Signing Nurse Info
                    Text(
                      'Signing Nurse: ${widget.currentNurseName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                    ),
                    const SizedBox(height: 8),

                    // Remarks
                    TextField(
                      controller: remarksController,
                      decoration: InputDecoration(
                        hintText: 'Optional notes (e.g. Taken with meals, site left arm...)',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(modalCtx).pop(),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Sign & Administer Dose'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: !confirmedRights
                              ? null
                              : () {
                                  Navigator.of(modalCtx).pop();
                                  final slotTime = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    _selectedDate.day,
                                    int.parse(slotKey.split(':')[0]),
                                    int.parse(slotKey.split(':')[1]),
                                  );

                                  final userRemarks = remarksController.text.trim();
                                  final taggedRemarks = userRemarks.isNotEmpty
                                      ? '[Slot:$slotKey] $userRemarks'
                                      : '[Slot:$slotKey]';

                                  widget.onAdministerDose(
                                    prescriptionId: prescription['id'],
                                    status: 'Given',
                                    remarks: taggedRemarks,
                                    administeredAt: slotTime.toUtc().toIso8601String(),
                                  );
                                },
                        ),
                      ],
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

  // ─── Omission & Refusal Modal ─────────────────────────────────────────────

  void _showOmissionRefusalModal(Map<String, dynamic> prescription, String slotKey) {
    String selectedCategory = 'Refused'; // 'Refused', 'Omitted', 'Delayed'
    String selectedReason = 'Patient Refused';
    final customReasonController = TextEditingController();

    final List<String> refusalReasons = [
      'Patient Refused (Personal Choice / Autonomy)',
      'Patient NPO / Fasting for Surgery or Procedure',
      'Patient Asleep / Rest Undisturbed per Order',
      'Patient Away from Ward (Radiology, OT, Dialysis)',
      'Physician Withheld / Clinical Hold Order',
      'Vitals Out of Range (Low BP / Bradycardia)',
      'Suspected Adverse Drug Reaction / Allergy',
      'Medication Out of Stock / Pharmacy Dispense Delay',
      'IV Line Infiltrated / Route Unavailable',
      'Other Clinical Justification',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Record Medication Omission or Refusal',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Medication Info
                    Text(
                      'Medication: ${prescription['medicine_name']} (${prescription['dosage']})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Status Category Toggle
                    const Text('Deviation Status *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCategoryRadio(
                          'Refused',
                          'Patient Refused',
                          selectedCategory,
                          (v) => setModalState(() => selectedCategory = v),
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryRadio(
                          'Omitted',
                          'Clinical Omission',
                          selectedCategory,
                          (v) => setModalState(() => selectedCategory = v),
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryRadio(
                          'Delayed',
                          'Dose Delayed',
                          selectedCategory,
                          (v) => setModalState(() => selectedCategory = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reason Dropdown
                    const Text('Primary Clinical Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          isExpanded: true,
                          items: refusalReasons.map((r) {
                            return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedReason = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Clinical Justification Notes
                    const Text('Nurse Notes / Justification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: customReasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter clinical details, notifying physician, or action taken...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(modalCtx).pop(),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.of(modalCtx).pop();
                            final fullRemark = customReasonController.text.trim().isNotEmpty
                                ? '$selectedReason: ${customReasonController.text.trim()}'
                                : selectedReason;

                            final slotTime = DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
                              int.parse(slotKey.split(':')[0]),
                              int.parse(slotKey.split(':')[1]),
                            );

                            final taggedRemarks = '[Slot:$slotKey] $fullRemark';

                            widget.onAdministerDose(
                              prescriptionId: prescription['id'],
                              status: selectedCategory,
                              remarks: taggedRemarks,
                              administeredAt: slotTime.toUtc().toIso8601String(),
                            );
                          },
                          child: const Text('Confirm & Log Deviation'),
                        ),
                      ],
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

  Widget _buildCategoryRadio(String val, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == val;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(val),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDetailBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
      ),
    );
  }

  // ─── Audit & History Log Tab ─────────────────────────────────────────────

  Widget _buildAuditHistoryTab() {
    final logs = widget.medicationLogs.where((l) {
      if (_historyFilter == 'All') return true;
      final s = (l['status'] ?? '').toString().toLowerCase();
      return s == _historyFilter.toLowerCase();
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          Row(
            children: [
              _buildHistoryFilterChip('All', 'All Logs (${widget.medicationLogs.length})'),
              const SizedBox(width: 8),
              _buildHistoryFilterChip('Given', 'Given'),
              const SizedBox(width: 8),
              _buildHistoryFilterChip('Omitted', 'Omitted'),
              const SizedBox(width: 8),
              _buildHistoryFilterChip('Refused', 'Refused'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (logs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text('No medication administration logs recorded yet.'),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (ctx, i) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final log = logs[index];
                final status = (log['status'] ?? 'Given').toString();
                final drugName = (log['medicine_name'] ?? 'Medication').toString();
                final dosage = (log['dosage'] ?? '').toString();
                final nurseName = (log['nurse_name'] ?? 'Nurse').toString();
                final rawRemarks = (log['remarks'] ?? '').toString();
                final remarks = _cleanRemarks(rawRemarks);
                final dateRaw = log['administered_at'] ?? log['created_at'];

                String timeStr = '--';
                if (dateRaw != null) {
                  try {
                    final dt = DateTime.parse(dateRaw.toString()).toLocal();
                    timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
                  } catch (_) {}
                }

                Color statusColor;
                IconData statusIcon;
                switch (status.toLowerCase()) {
                  case 'given':
                    statusColor = const Color(0xFF10B981);
                    statusIcon = Icons.check_circle_outline;
                    break;
                  case 'refused':
                    statusColor = const Color(0xFF8B5CF6);
                    statusIcon = Icons.cancel_outlined;
                    break;
                  case 'omitted':
                  case 'missed':
                  default:
                    statusColor = const Color(0xFFEF4444);
                    statusIcon = Icons.warning_amber_rounded;
                    break;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Icon(statusIcon, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                drugName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                              ),
                              if (dosage.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('($dosage)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                              const Spacer(),
                              Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Signed by: $nurseName',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          if (remarks.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                remarks,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilterChip(String key, String label) {
    final isSelected = _historyFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) setState(() => _historyFilter = key);
      },
    );
  }
}
