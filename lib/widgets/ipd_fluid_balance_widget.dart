import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';

/// 24-Hour Intake/Output and Fluid Balance Monitoring Widget
class IpdFluidBalanceWidget extends StatefulWidget {
  final Map<String, dynamic> admission;
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic> summary;
  final String currentStaffName;
  final bool isMobile;
  final VoidCallback? onRefresh;
  final Future<void> Function({
    required String entryType,
    required String category,
    required double volumeMl,
    required String route,
    required String fluidDescription,
    required String shift,
    DateTime? recordedAt,
  }) onAddFluidLog;
  final Future<void> Function(int logId)? onDeleteFluidLog;

  const IpdFluidBalanceWidget({
    super.key,
    required this.admission,
    required this.records,
    required this.summary,
    required this.currentStaffName,
    required this.isMobile,
    required this.onAddFluidLog,
    this.onDeleteFluidLog,
    this.onRefresh,
  });

  @override
  State<IpdFluidBalanceWidget> createState() => _IpdFluidBalanceWidgetState();
}

double _safeToDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class _IpdFluidBalanceWidgetState extends State<IpdFluidBalanceWidget> {
  final DateTime _selectedDate = DateTime.now();
  String _filterType = 'All'; // 'All', 'Intake', 'Output'
  String _selectedShiftFilter = 'All'; // 'All', 'Morning', 'Afternoon', 'Night'

  @override
  Widget build(BuildContext context) {
    final double totalIntake = _safeToDouble(widget.summary['total_intake_ml']);
    final double totalOutput = _safeToDouble(widget.summary['total_output_ml']);
    final double netBalance = widget.summary['net_balance_ml'] != null
        ? _safeToDouble(widget.summary['net_balance_ml'])
        : (totalIntake - totalOutput);

    final filteredRecords = widget.records.where((r) {
      final entryType = (r['entry_type'] ?? '').toString();
      final shift = (r['shift'] ?? '').toString();

      if (_filterType != 'All' && entryType != _filterType) return false;
      if (_selectedShiftFilter != 'All' && shift != _selectedShiftFilter) return false;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top 24-Hour Fluid Balance Hero & KPI Summary ─────────────────
          _buildFluidHeroHeader(totalIntake, totalOutput, netBalance),
          const SizedBox(height: 16),

          // ─── Shift Breakdown & Clinical Alerts ─────────────────────────────
          _buildShiftBreakdownAndAlerts(totalIntake, totalOutput, netBalance),
          const SizedBox(height: 20),

          // ─── Graphical Intake vs Output Timeline Chart ─────────────────────
          _buildIntakeOutputChartCard(),
          const SizedBox(height: 20),

          // ─── Filter & Logs Table ───────────────────────────────────────────
          _buildLogsCard(filteredRecords),
        ],
      ),
    );
  }

  // ─── Hero KPI Header ─────────────────────────────────────────────────────

  Widget _buildFluidHeroHeader(double totalIntake, double totalOutput, double netBalance) {
    Color balanceColor;
    String balanceLabel;
    IconData balanceIcon;

    if (netBalance > 500) {
      balanceColor = const Color(0xFF2563EB); // Positive overload blue
      balanceLabel = 'Positive Balance (+${netBalance.toStringAsFixed(0)} mL)';
      balanceIcon = Icons.arrow_upward_rounded;
    } else if (netBalance < -500) {
      balanceColor = Colors.orange.shade800; // Negative deficit
      balanceLabel = 'Negative Balance (${netBalance.toStringAsFixed(0)} mL)';
      balanceIcon = Icons.arrow_downward_rounded;
    } else {
      balanceColor = AppTheme.secondaryColor; // Healthy balanced green
      balanceLabel = 'Balanced (${netBalance >= 0 ? '+' : ''}${netBalance.toStringAsFixed(0)} mL)';
      balanceIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water_drop_outlined, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('fluid_balance_title', fallback: '24-Hour Fluid Balance & Intake/Output'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Continuous 24-hr fluid shift monitoring (${DateFormat('dd MMM yyyy').format(_selectedDate)})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(widget.isMobile ? 'Log' : 'Record I/O'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddFluidLogModal,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // 3 Big Metric Columns
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 750;
            if (isNarrow) {
              return Column(
                children: [
                  _buildMetricBox('Total 24h Intake', '${totalIntake.toStringAsFixed(0)} mL', const Color(0xFF0284C7), Icons.local_drink_outlined, 'Oral, IV Fluids, Blood, Feeds'),
                  const SizedBox(height: 12),
                  _buildMetricBox('Total 24h Output', '${totalOutput.toStringAsFixed(0)} mL', const Color(0xFFD97706), Icons.outbox_rounded, 'Urine, Vomitus, Stool, Drains'),
                  const SizedBox(height: 12),
                  _buildNetBalanceBox(netBalance, balanceLabel, balanceColor, balanceIcon),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _buildMetricBox('Total 24h Intake', '${totalIntake.toStringAsFixed(0)} mL', const Color(0xFF0284C7), Icons.local_drink_outlined, 'Oral, IV, Blood, Feeds'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricBox('Total 24h Output', '${totalOutput.toStringAsFixed(0)} mL', const Color(0xFFD97706), Icons.outbox_rounded, 'Urine, Stool, Vomitus, Drains'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNetBalanceBox(netBalance, balanceLabel, balanceColor, balanceIcon),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String title, String value, Color color, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNetBalanceBox(double netBalance, String balanceLabel, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Net 24h Fluid Balance',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${netBalance >= 0 ? '+' : ''}${netBalance.toStringAsFixed(0)} mL',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              balanceLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shift Breakdown & Clinical Alerts ───────────────────────────────────

  Widget _buildShiftBreakdownAndAlerts(double totalIntake, double totalOutput, double netBalance) {
    final shiftSummary = widget.summary['shift_summary'] as Map<String, dynamic>? ?? {};
    final morning = shiftSummary['Morning'] as Map<String, dynamic>? ?? {};
    final afternoon = shiftSummary['Afternoon'] as Map<String, dynamic>? ?? {};
    final night = shiftSummary['Night'] as Map<String, dynamic>? ?? {};

    // Oliguria check: total output < 400 mL across 24h
    final bool isOliguria = totalOutput > 0 && totalOutput < 400;
    // Fluid Overload check: net balance > 1500 mL
    final bool isFluidOverload = netBalance > 1500;

    return Column(
      children: [
        if (isOliguria || isFluidOverload) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isFluidOverload ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFluidOverload ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: isFluidOverload ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFluidOverload
                            ? 'CLINICAL ALERT: Marked Positive Fluid Overload (> +1500 mL)'
                            : 'CLINICAL ALERT: Low Urine/Fluid Output (< 400 mL/24h - Possible Oliguria)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isFluidOverload ? const Color(0xFF1E40AF) : const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFluidOverload
                            ? 'Monitor for peripheral edema, jugular venous distention, or pulmonary congestion. Review diuretic and IV fluid infusion orders.'
                            : 'Assess renal perfusion, patency of catheter/drain, and evaluate patient for prerenal dehydration or acute kidney injury.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isFluidOverload ? const Color(0xFF1E40AF) : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Shift breakdown cards
        Container(
          padding: const EdgeInsets.all(18),
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
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Hospital Nursing Shifts Breakdown',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryColor),
                  ),
                  const Spacer(),
                  Text(
                    '24h Hospital Cycle',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                if (isNarrow) {
                  return Column(
                    children: [
                      _buildShiftCard('Morning Shift (08:00 - 14:00)', morning, Icons.wb_sunny_outlined, const Color(0xFFF59E0B)),
                      const SizedBox(height: 10),
                      _buildShiftCard('Afternoon Shift (14:00 - 20:00)', afternoon, Icons.wb_twilight_rounded, const Color(0xFF3B82F6)),
                      const SizedBox(height: 10),
                      _buildShiftCard('Night Shift (20:00 - 08:00)', night, Icons.nightlight_round, const Color(0xFF6366F1)),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: _buildShiftCard('Morning (08:00 - 14:00)', morning, Icons.wb_sunny_outlined, const Color(0xFFF59E0B))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildShiftCard('Afternoon (14:00 - 20:00)', afternoon, Icons.wb_twilight_rounded, const Color(0xFF3B82F6))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildShiftCard('Night (20:00 - 08:00)', night, Icons.nightlight_round, const Color(0xFF6366F1))),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftCard(String title, Map<String, dynamic> data, IconData icon, Color color) {
    final double inVol = _safeToDouble(data['intake']);
    final double outVol = _safeToDouble(data['output']);
    final double diff = inVol - outVol;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Intake:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text('${inVol.toStringAsFixed(0)} mL', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Output:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text('${outVol.toStringAsFixed(0)} mL', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706))),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shift Balance:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
              Text(
                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)} mL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: diff >= 0 ? const Color(0xFF059669) : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Graphical Intake vs Output Timeline Chart ───────────────────────────

  Widget _buildIntakeOutputChartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            children: [
              const Icon(Icons.bar_chart_rounded, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Intake vs Output Distribution',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
              ),
              const Spacer(),
              // Legend
              Row(
                children: [
                  _buildLegendItem('Intake', const Color(0xFF0284C7)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Output', const Color(0xFFD97706)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bar Chart Canvas
          SizedBox(
            height: 180,
            width: double.infinity,
            child: widget.records.isEmpty
                ? Center(
                    child: Text(
                      'No fluid entries recorded today. Click "Record I/O" to log.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: _FluidChartPainter(widget.records),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── Intake & Output Logs Table ──────────────────────────────────────────

  Widget _buildLogsCard(List<Map<String, dynamic>> records) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'All Logs (${widget.records.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Intake', 'Intake Only'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Output', 'Output Only'),
                        const SizedBox(width: 16),
                        // Shift filter popup menu
                        PopupMenuButton<String>(
                          initialValue: _selectedShiftFilter,
                          tooltip: 'Filter by Shift',
                          onSelected: (val) {
                            setState(() => _selectedShiftFilter = val);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'All', child: Text('All Shifts', style: TextStyle(fontSize: 13))),
                            PopupMenuItem(value: 'Morning', child: Text('Morning Shift (08-14h)', style: TextStyle(fontSize: 13))),
                            PopupMenuItem(value: 'Afternoon', child: Text('Afternoon Shift (14-20h)', style: TextStyle(fontSize: 13))),
                            PopupMenuItem(value: 'Night', child: Text('Night Shift (20-08h)', style: TextStyle(fontSize: 13))),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedShiftFilter == 'All'
                                  ? const Color(0xFFF1F5F9)
                                  : AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedShiftFilter == 'All'
                                    ? Colors.transparent
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: _selectedShiftFilter == 'All'
                                      ? AppTheme.textSecondaryColor
                                      : AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedShiftFilter == 'All'
                                      ? 'All Shifts'
                                      : '$_selectedShiftFilter Shift',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedShiftFilter == 'All'
                                        ? AppTheme.textPrimaryColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: _selectedShiftFilter == 'All'
                                      ? AppTheme.textSecondaryColor
                                      : AppTheme.primaryColor,
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
            ),
          ),
          const Divider(height: 1),

          // Table / List
          if (records.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.format_list_bulleted, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('No intake/output entries match the filter.', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final r = records[i];
                final entryType = (r['entry_type'] ?? 'Intake').toString();
                final isIntake = entryType == 'Intake';
                final cat = (r['category'] ?? '--').toString();
                final vol = (r['volume_ml'] ?? 0).toString();
                final route = (r['route'] ?? '').toString();
                final desc = (r['fluid_description'] ?? '').toString();
                final nurse = (r['recorded_by'] ?? 'Staff Nurse').toString();
                final shift = (r['shift'] ?? 'Morning').toString();
                final dateRaw = r['recorded_at'] ?? r['created_at'];

                String timeStr = '--';
                if (dateRaw != null) {
                  try {
                    final dt = DateTime.parse(dateRaw.toString()).toLocal();
                    timeStr = DateFormat('hh:mm a').format(dt);
                  } catch (_) {}
                }

                final Color typeColor = isIntake ? const Color(0xFF0284C7) : const Color(0xFFD97706);
                final IconData typeIcon = isIntake ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: typeColor.withValues(alpha: 0.1),
                        child: Icon(typeIcon, color: typeColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  cat,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                                ),
                                if (route.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(route, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  '${isIntake ? '+' : '-'}$vol mL',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: typeColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text('$timeStr • $shift Shift • By $nurse', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text('($desc)', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.onDeleteFluidLog != null && r['id'] != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                          tooltip: 'Delete Entry',
                          onPressed: () => _confirmDeleteLog(r['id']),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filterType == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
      ),
      onSelected: (val) {
        if (val) setState(() => _filterType = key);
      },
    );
  }

  // ─── Add Fluid Log Modal ─────────────────────────────────────────────────

  void _showAddFluidLogModal() {
    String entryType = 'Intake'; // or 'Output'
    String category = 'Oral Fluids';
    String route = 'Oral';
    String shift = 'Morning';
    final volumeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Initial shift based on current time
    final curHour = DateTime.now().hour;
    if (curHour >= 6 && curHour < 14) {
      shift = 'Morning';
    } else if (curHour >= 14 && curHour < 21) {
      shift = 'Afternoon';
    } else {
      shift = 'Night';
    }

    final intakePresets = [
      {'name': 'Water 100ml', 'vol': '100', 'cat': 'Oral Fluids', 'route': 'Oral'},
      {'name': 'Water 250ml', 'vol': '250', 'cat': 'Oral Fluids', 'route': 'Oral'},
      {'name': 'Normal Saline 500ml', 'vol': '500', 'cat': 'IV Fluids', 'route': 'IV Line'},
      {'name': 'Ringer Lactate 500ml', 'vol': '500', 'cat': 'IV Fluids', 'route': 'IV Line'},
      {'name': 'Dextrose 5% 500ml', 'vol': '500', 'cat': 'IV Fluids', 'route': 'IV Line'},
      {'name': 'Ryle Tube Feed 200ml', 'vol': '200', 'cat': 'Enteral/Tube Feed', 'route': 'Ryle Tube'},
      {'name': 'Blood PRBC 350ml', 'vol': '350', 'cat': 'Blood Products', 'route': 'Blood Line'},
    ];

    final outputPresets = [
      {'name': 'Urine 150ml', 'vol': '150', 'cat': 'Urine Output', 'route': 'Voided'},
      {'name': 'Urine 300ml', 'vol': '300', 'cat': 'Urine Output', 'route': 'Voided'},
      {'name': 'Catheter Bag 500ml', 'vol': '500', 'cat': 'Urine Output', 'route': 'Foley Catheter'},
      {'name': 'Vomitus 150ml', 'vol': '150', 'cat': 'Vomitus', 'route': 'Oral/Gastric'},
      {'name': 'Stool / Diarrhea 200ml', 'vol': '200', 'cat': 'Stool', 'route': 'Rectal'},
      {'name': 'Surgical Drain 100ml', 'vol': '100', 'cat': 'Drains', 'route': 'Abdominal Drain'},
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isIntake = entryType == 'Intake';
            final activePresets = isIntake ? intakePresets : outputPresets;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 520,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                                color: (isIntake ? const Color(0xFF0284C7) : const Color(0xFFD97706)).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isIntake ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                                color: isIntake ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Record ${isIntake ? 'Fluid Intake' : 'Fluid Output'}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(modalCtx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Segmented Toggle Intake vs Output
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      entryType = 'Intake';
                                      category = 'Oral Fluids';
                                      route = 'Oral';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isIntake ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: isIntake ? AppTheme.cardShadow : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add, size: 14, color: isIntake ? const Color(0xFF0284C7) : Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('Intake (+)', style: TextStyle(fontWeight: isIntake ? FontWeight.bold : FontWeight.w500, color: isIntake ? const Color(0xFF0284C7) : Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      entryType = 'Output';
                                      category = 'Urine Output';
                                      route = 'Voided';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !isIntake ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: !isIntake ? AppTheme.cardShadow : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.remove, size: 14, color: !isIntake ? const Color(0xFFD97706) : Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('Output (-)', style: TextStyle(fontWeight: !isIntake ? FontWeight.bold : FontWeight.w500, color: !isIntake ? const Color(0xFFD97706) : Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quick Presets
                        const Text('Quick Clinical Presets', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: activePresets.map((p) {
                            return ActionChip(
                              label: Text(p['name']!, style: const TextStyle(fontSize: 11)),
                              backgroundColor: const Color(0xFFF8FAFC),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: Colors.grey.shade300)),
                              onPressed: () {
                                setModalState(() {
                                  volumeCtrl.text = p['vol']!;
                                  category = p['cat']!;
                                  route = p['route']!;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Volume Input (mL)
                        const Text('Volume (mL) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: volumeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            hintText: 'e.g. 250, 500',
                            suffixText: 'mL',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Volume in mL is required';
                            final num? n = num.tryParse(val.trim());
                            if (n == null || n <= 0) return 'Must be a valid positive volume in mL';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Category & Route Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: category,
                                        items: (isIntake
                                                ? ['Oral Fluids', 'IV Fluids', 'Blood Products', 'Enteral/Tube Feed', 'Medication Infusion', 'Other Intake']
                                                : ['Urine Output', 'Vomitus', 'Stool', 'Drains', 'Gastric Aspirate', 'Other Output'])
                                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setModalState(() => category = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: route,
                                        items: (isIntake
                                                ? ['Oral', 'IV Line', 'Central Line', 'Ryle Tube', 'PEG Tube', 'Blood Line']
                                                : ['Voided', 'Foley Catheter', 'Oral/Gastric', 'Rectal', 'Abdominal Drain', 'Chest Drain'])
                                            .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12))))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setModalState(() => route = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Shift & Description
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      initialValue: shift,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'Morning', child: Text('Morning (08-14h)', style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon (14-20h)', style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(value: 'Night', child: Text('Night (20-08h)', style: TextStyle(fontSize: 12))),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setModalState(() => shift = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Notes / Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: descCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Pale amber, Clear...',
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
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
                                backgroundColor: isIntake ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final vol = double.parse(volumeCtrl.text.trim());
                                Navigator.of(modalCtx).pop();

                                await widget.onAddFluidLog(
                                  entryType: entryType,
                                  category: category,
                                  volumeMl: vol,
                                  route: route,
                                  fluidDescription: descCtrl.text.trim(),
                                  shift: shift,
                                  recordedAt: DateTime.now(),
                                );
                              },
                              child: Text('Save ${isIntake ? 'Intake' : 'Output'}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLog(int logId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Are you sure you want to delete this fluid balance record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteFluidLog?.call(logId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter for Graphical Fluid Distribution ─────────────────────────

class _FluidChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> records;

  _FluidChartPainter(this.records);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paintGrid = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    // Draw 3 horizontal gridlines
    for (int i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Bucket into 6 time intervals of 4 hours each across 24 hours
    // (00-04, 04-08, 08-12, 12-16, 16-20, 20-24)
    final List<double> intakeBuckets = List.filled(6, 0.0);
    final List<double> outputBuckets = List.filled(6, 0.0);
    final bucketLabels = ['00-04h', '04-08h', '08-12h', '12-16h', '16-20h', '20-24h'];

    for (final r in records) {
      final vol = _safeToDouble(r['volume_ml']);
      final isIntake = r['entry_type'] == 'Intake';
      final rawDate = r['recorded_at'] ?? r['created_at'];
      if (rawDate == null) continue;

      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        final bucketIndex = (dt.hour ~/ 4).clamp(0, 5);
        if (isIntake) {
          intakeBuckets[bucketIndex] += vol;
        } else {
          outputBuckets[bucketIndex] += vol;
        }
      } catch (_) {}
    }

    double maxVol = 500.0;
    for (int i = 0; i < 6; i++) {
      if (intakeBuckets[i] > maxVol) maxVol = intakeBuckets[i];
      if (outputBuckets[i] > maxVol) maxVol = outputBuckets[i];
    }
    maxVol = (maxVol * 1.25); // headroom

    final paintIntake = Paint()..color = const Color(0xFF0284C7);
    final paintOutput = Paint()..color = const Color(0xFFD97706);

    final colWidth = size.width / 6;
    final barWidth = (colWidth * 0.32).clamp(8.0, 24.0);

    for (int i = 0; i < 6; i++) {
      final centerX = (i * colWidth) + (colWidth / 2);

      // Intake bar
      final inH = (intakeBuckets[i] / maxVol) * (size.height - 30);
      final inRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth - 2, size.height - 24 - inH, barWidth, inH),
        const Radius.circular(4),
      );
      canvas.drawRRect(inRect, paintIntake);

      // Output bar
      final outH = (outputBuckets[i] / maxVol) * (size.height - 30);
      final outRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + 2, size.height - 24 - outH, barWidth, outH),
        const Radius.circular(4),
      );
      canvas.drawRRect(outRect, paintOutput);

      // X-axis label
      final tp = TextPainter(
        text: TextSpan(
          text: bucketLabels[i],
          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX - (tp.width / 2), size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _FluidChartPainter oldDelegate) => true;
}
