import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';

/// Graphical clinical TPR (Temperature, Pulse, Respiration) & BP Chart Widget
class TprChartsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> vitals;
  final VoidCallback? onLogVitalsPressed;
  final bool isMobile;

  const TprChartsWidget({
    super.key,
    required this.vitals,
    this.onLogVitalsPressed,
    this.isMobile = false,
  });

  @override
  State<TprChartsWidget> createState() => _TprChartsWidgetState();
}

enum TprChartMode {
  combined,
  temperature,
  pulse,
  respiration,
  bloodPressure,
  table;

  String get label {
    switch (this) {
      case TprChartMode.combined:
        return 'Combined TPR + BP';
      case TprChartMode.temperature:
        return 'Temperature (°F)';
      case TprChartMode.pulse:
        return 'Pulse (BPM)';
      case TprChartMode.respiration:
        return 'Respiration (breaths/min)';
      case TprChartMode.bloodPressure:
        return 'Blood Pressure (mmHg)';
      case TprChartMode.table:
        return 'Log Table';
    }
  }

  IconData get icon {
    switch (this) {
      case TprChartMode.combined:
        return Icons.auto_graph_rounded;
      case TprChartMode.temperature:
        return Icons.thermostat_outlined;
      case TprChartMode.pulse:
        return Icons.favorite_border_rounded;
      case TprChartMode.respiration:
        return Icons.air_rounded;
      case TprChartMode.bloodPressure:
        return Icons.speed_rounded;
      case TprChartMode.table:
        return Icons.table_chart_outlined;
    }
  }

  Color get color {
    switch (this) {
      case TprChartMode.combined:
        return AppTheme.primaryColor;
      case TprChartMode.temperature:
        return const Color(0xFFE11D48); // Rose / Red
      case TprChartMode.pulse:
        return const Color(0xFF2563EB); // Royal Blue
      case TprChartMode.respiration:
        return const Color(0xFF059669); // Emerald
      case TprChartMode.bloodPressure:
        return const Color(0xFF7C3AED); // Purple
      case TprChartMode.table:
        return const Color(0xFF475569);
    }
  }
}

class _TprChartsWidgetState extends State<TprChartsWidget> {
  TprChartMode _chartMode = TprChartMode.combined;
  String _timeRange = 'All'; // 'All', '24h', '48h', '7d'
  int? _hoveredIndex;

  List<Map<String, dynamic>> get _sortedVitals {
    final list = List<Map<String, dynamic>>.from(widget.vitals);
    list.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return aDate.compareTo(bDate); // Oldest to newest for charting
    });
    return list;
  }

  List<Map<String, dynamic>> get _filteredVitals {
    final sorted = _sortedVitals;
    if (sorted.isEmpty || _timeRange == 'All') return sorted;

    final now = DateTime.now();
    Duration duration;
    if (_timeRange == '24h') {
      duration = const Duration(hours: 24);
    } else if (_timeRange == '48h') {
      duration = const Duration(hours: 48);
    } else {
      duration = const Duration(days: 7);
    }

    final cutoff = now.subtract(duration);
    return sorted.where((v) {
      final dt = DateTime.tryParse(v['created_at']?.toString() ?? '');
      return dt != null && dt.isAfter(cutoff);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vitals.isEmpty) {
      return _buildEmptyVitals();
    }

    final data = _filteredVitals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header & KPI Metrics Bar ──────────────────────────────────────
        _buildStatsBar(),
        const SizedBox(height: 16),

        // ─── Chart Toolbar ────────────────────────────────────────────────
        _buildToolbar(),
        const SizedBox(height: 16),

        // ─── Chart Canvas or Table View ───────────────────────────────────
        if (_chartMode == TprChartMode.table)
          _buildTableView(data)
        else
          _buildChartContainer(data),
      ],
    );
  }

  // ─── KPI Stats Bar ───────────────────────────────────────────────────────

  Widget _buildStatsBar() {
    final list = _sortedVitals;
    if (list.isEmpty) return const SizedBox.shrink();

    final latest = list.last;
    final tempVal = double.tryParse(latest['temperature']?.toString() ?? '');
    final pulseVal = int.tryParse(latest['pulse']?.toString() ?? '');
    final respVal = int.tryParse(latest['respiratory_rate']?.toString() ?? '');
    final sysVal = int.tryParse(latest['blood_pressure_systolic']?.toString() ?? '');
    final diaVal = int.tryParse(latest['blood_pressure_diastolic']?.toString() ?? '');

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
                child: const Icon(Icons.show_chart_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('clinical_tpr_heading', fallback: 'Clinical TPR & Vitals Progression'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Latest Reading: ${_formatDate(latest['created_at'])} • ${list.length} Total Recordings',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              if (widget.onLogVitalsPressed != null)
                ElevatedButton.icon(
                  onPressed: widget.onLogVitalsPressed,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Record Vitals', style: TextStyle(fontSize: 12)),
                  style: AppTheme.primaryButton.copyWith(
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Vitals KPI Tiles
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final tiles = [
                _buildKpiTile(
                  label: 'Temperature (T)',
                  value: tempVal != null ? '${tempVal.toStringAsFixed(1)} °F' : '--',
                  normalRange: 'Normal: 97.8 - 99.1 °F',
                  isAbnormal: tempVal != null && (tempVal < 97.0 || tempVal > 100.4),
                  color: const Color(0xFFE11D48),
                  icon: Icons.thermostat,
                ),
                _buildKpiTile(
                  label: 'Pulse Rate (P)',
                  value: pulseVal != null ? '$pulseVal bpm' : '--',
                  normalRange: 'Normal: 60 - 100 bpm',
                  isAbnormal: pulseVal != null && (pulseVal < 60 || pulseVal > 100),
                  color: const Color(0xFF2563EB),
                  icon: Icons.favorite,
                ),
                _buildKpiTile(
                  label: 'Respiration (R)',
                  value: respVal != null ? '$respVal /min' : '--',
                  normalRange: 'Normal: 12 - 20 bpm',
                  isAbnormal: respVal != null && (respVal < 12 || respVal > 22),
                  color: const Color(0xFF059669),
                  icon: Icons.air,
                ),
                _buildKpiTile(
                  label: 'Blood Pressure (BP)',
                  value: (sysVal != null && diaVal != null) ? '$sysVal / $diaVal mmHg' : '--',
                  normalRange: 'Normal: 120/80 mmHg',
                  isAbnormal: (sysVal != null && (sysVal < 90 || sysVal > 140)) ||
                      (diaVal != null && (diaVal < 60 || diaVal > 90)),
                  color: const Color(0xFF7C3AED),
                  icon: Icons.speed,
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: tiles.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: t)).toList(),
                );
              }

              return Row(
                children: tiles
                    .map((t) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: t,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String label,
    required String value,
    required String normalRange,
    required bool isAbnormal,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAbnormal ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAbnormal ? color.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: isAbnormal ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isAbnormal ? color : AppTheme.textPrimaryColor,
                ),
              ),
              if (isAbnormal) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ALERT',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            normalRange,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── Toolbar (Chart Mode Switcher + Timeline Filter) ──────────────────────

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: widget.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModeChips(),
                const SizedBox(height: 8),
                _buildTimelineFilter(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildModeChips()),
                const SizedBox(width: 16),
                _buildTimelineFilter(),
              ],
            ),
    );
  }

  Widget _buildModeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TprChartMode.values.map((mode) {
          final isSelected = _chartMode == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              avatar: Icon(
                mode.icon,
                size: 14,
                color: isSelected ? Colors.white : mode.color,
              ),
              label: Text(mode.label),
              selected: isSelected,
              selectedColor: mode.color,
              backgroundColor: const Color(0xFFF1F5F9),
              labelStyle: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? mode.color : Colors.transparent,
              ),
              onSelected: (val) {
                if (val) setState(() => _chartMode = mode);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineFilter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.history, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 6),
        _buildTimeFilterBtn('All', 'All Time'),
        _buildTimeFilterBtn('7d', '7 Days'),
        _buildTimeFilterBtn('48h', '48 Hours'),
        _buildTimeFilterBtn('24h', '24 Hours'),
      ],
    );
  }

  Widget _buildTimeFilterBtn(String key, String label) {
    final isSelected = _timeRange == key;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () => setState(() => _timeRange = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Graphical Chart Container ───────────────────────────────────────────

  Widget _buildChartContainer(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Text('No vitals records in selected time window.'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Legend Bar
          _buildChartLegend(),
          const SizedBox(height: 16),

          // Custom Paint Canvas
          SizedBox(
            height: 380,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (event) {
                    final dx = event.localPosition.dx;
                    final chartWidth = constraints.maxWidth - 60; // Left padding 60
                    if (data.length > 1 && dx >= 60 && dx <= constraints.maxWidth) {
                      final relX = dx - 60;
                      final step = chartWidth / (data.length - 1);
                      final index = (relX / step).round().clamp(0, data.length - 1);
                      setState(() => _hoveredIndex = index);
                    }
                  },
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 380),
                    painter: _ClinicalTprPainter(
                      data: data,
                      mode: _chartMode,
                      hoveredIndex: _hoveredIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Hovered Data Point Detail Popover
          if (_hoveredIndex != null && _hoveredIndex! < data.length)
            _buildHoveredDetailsCard(data[_hoveredIndex!]),
        ],
      ),
    );
  }

  Widget _buildChartLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (_chartMode == TprChartMode.combined || _chartMode == TprChartMode.temperature)
          _buildLegendItem('Temperature (°F)', const Color(0xFFE11D48), Icons.change_history),
        if (_chartMode == TprChartMode.combined || _chartMode == TprChartMode.pulse)
          _buildLegendItem('Pulse (bpm)', const Color(0xFF2563EB), Icons.circle),
        if (_chartMode == TprChartMode.combined || _chartMode == TprChartMode.respiration)
          _buildLegendItem('Respiration (/min)', const Color(0xFF059669), Icons.square),
        if (_chartMode == TprChartMode.combined || _chartMode == TprChartMode.bloodPressure) ...[
          _buildLegendItem('Systolic BP (mmHg)', const Color(0xFF7C3AED), Icons.arrow_upward),
          _buildLegendItem('Diastolic BP (mmHg)', const Color(0xFFA855F7), Icons.arrow_downward),
        ],
        _buildLegendItem('Normal Band', const Color(0xFF10B981).withValues(alpha: 0.15), Icons.rectangle),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildHoveredDetailsCard(Map<String, dynamic> item) {
    final temp = item['temperature'];
    final pulse = item['pulse'];
    final resp = item['respiratory_rate'];
    final sys = item['blood_pressure_systolic'];
    final dia = item['blood_pressure_diastolic'];
    final spo2 = item['spo2'];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            'Reading at ${_formatDate(item['created_at'])}: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          Expanded(
            child: Wrap(
              spacing: 12,
              children: [
                if (temp != null) Text('Temp: $temp°F', style: const TextStyle(fontSize: 12, color: Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                if (pulse != null) Text('Pulse: $pulse bpm', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                if (resp != null) Text('Resp: $resp /min', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                if (sys != null && dia != null) Text('BP: $sys/$dia mmHg', style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                if (spo2 != null) Text('SpO2: $spo2%', style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Table View ──────────────────────────────────────────────────────────

  Widget _buildTableView(List<Map<String, dynamic>> data) {
    final reversed = List<Map<String, dynamic>>.from(data.reversed);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Temp (°F)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Pulse (bpm)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Resp (/min)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('BP (mmHg)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('SpO2 (%)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: reversed.map((v) {
              final temp = double.tryParse(v['temperature']?.toString() ?? '');
              final pulse = int.tryParse(v['pulse']?.toString() ?? '');
              final resp = int.tryParse(v['respiratory_rate']?.toString() ?? '');
              final sys = int.tryParse(v['blood_pressure_systolic']?.toString() ?? '');
              final dia = int.tryParse(v['blood_pressure_diastolic']?.toString() ?? '');
              final spo2 = int.tryParse(v['spo2']?.toString() ?? '');

              final isAbnormal = (temp != null && (temp < 97.0 || temp > 100.4)) ||
                  (pulse != null && (pulse < 60 || pulse > 100)) ||
                  (resp != null && (resp < 12 || resp > 22)) ||
                  (sys != null && (sys < 90 || sys > 140)) ||
                  (dia != null && (dia < 60 || dia > 90)) ||
                  (spo2 != null && spo2 < 94);

              return DataRow(
                color: isAbnormal ? WidgetStateProperty.all(const Color(0xFFFEF2F2)) : null,
                cells: [
                  DataCell(Text(_formatDate(v['created_at']))),
                  DataCell(Text(temp != null ? '${temp.toStringAsFixed(1)} °F' : '--')),
                  DataCell(Text(pulse != null ? '$pulse bpm' : '--')),
                  DataCell(Text(resp != null ? '$resp /min' : '--')),
                  DataCell(Text((sys != null && dia != null) ? '$sys / $dia' : '--')),
                  DataCell(Text(spo2 != null ? '$spo2 %' : '--')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAbnormal ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAbnormal ? 'ABNORMAL' : 'NORMAL',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyVitals() {
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
          Icon(Icons.monitor_heart_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No TPR or Vitals recordings logged yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 6),
          const Text(
            'Record patient vitals to generate real-time graphical TPR trend charts',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
          ),
          if (widget.onLogVitalsPressed != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onLogVitalsPressed,
              icon: const Icon(Icons.add),
              label: const Text('Record Patient Vitals'),
              style: AppTheme.primaryButton,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '--';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd/MM hh:mm a').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }
}

// ─── Custom Painter for Hospital Chart Paper & Graphical TPR Lines ─────────

class _ClinicalTprPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final TprChartMode mode;
  final int? hoveredIndex;

  _ClinicalTprPainter({
    required this.data,
    required this.mode,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftMargin = 55.0;
    const double bottomMargin = 30.0;
    const double topMargin = 15.0;
    const double rightMargin = 20.0;

    final double chartWidth = size.width - leftMargin - rightMargin;
    final double chartHeight = size.height - topMargin - bottomMargin;

    if (chartWidth <= 0 || chartHeight <= 0 || data.isEmpty) return;

    // 1. Draw Grid Lines (Clinical Chart Paper style)
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    final dottedGridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 0.8;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Horizontal Y-Axis Guideline ticks (5 steps)
    const int yDivisions = 5;
    for (int i = 0; i <= yDivisions; i++) {
      final y = topMargin + (chartHeight / yDivisions) * i;
      canvas.drawLine(Offset(leftMargin, y), Offset(leftMargin + chartWidth, y), gridPaint);
    }

    // X-Axis baseline
    canvas.drawLine(
      Offset(leftMargin, topMargin + chartHeight),
      Offset(leftMargin + chartWidth, topMargin + chartHeight),
      gridPaint..strokeWidth = 1.5..color = Colors.grey.shade400,
    );

    // Range determinations based on selected mode
    double minY = 0;
    double maxY = 200;

    if (mode == TprChartMode.temperature) {
      minY = 95.0;
      maxY = 106.0;
    } else if (mode == TprChartMode.pulse) {
      minY = 40.0;
      maxY = 160.0;
    } else if (mode == TprChartMode.respiration) {
      minY = 8.0;
      maxY = 40.0;
    } else if (mode == TprChartMode.bloodPressure) {
      minY = 40.0;
      maxY = 220.0;
    } else {
      // Combined normalized scale (0 - 100% or multi-axis baseline)
      minY = 0;
      maxY = 180;
    }

    // Draw Y-Axis Value Labels
    for (int i = 0; i <= yDivisions; i++) {
      final y = topMargin + (chartHeight / yDivisions) * (yDivisions - i);
      final val = minY + ((maxY - minY) / yDivisions) * i;
      final label = val.toStringAsFixed(mode == TprChartMode.temperature ? 1 : 0);

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftMargin - textPainter.width - 8, y - textPainter.height / 2));
    }

    // Draw X-Axis Time Labels and Vertical Grid Lines
    final int count = data.length;
    final double stepX = count > 1 ? chartWidth / (count - 1) : 0;

    for (int i = 0; i < count; i++) {
      final x = leftMargin + (stepX * i);
      canvas.drawLine(Offset(x, topMargin), Offset(x, topMargin + chartHeight), dottedGridPaint);

      // Only print every N labels if many points
      final int stepInterval = count > 10 ? (count / 6).ceil() : 1;
      if (i % stepInterval == 0 || i == count - 1) {
        final dateStr = data[i]['created_at']?.toString();
        String timeLabel = '';
        if (dateStr != null) {
          try {
            final dt = DateTime.parse(dateStr).toLocal();
            timeLabel = DateFormat('dd/MM HH:mm').format(dt);
          } catch (_) {}
        }
        textPainter.text = TextSpan(
          text: timeLabel,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, topMargin + chartHeight + 6));
      }
    }

    // Draw Shaded Normal Bands where relevant
    if (mode == TprChartMode.temperature) {
      _drawNormalBand(canvas, leftMargin, chartWidth, topMargin, chartHeight, 97.8, 99.1, minY, maxY);
    } else if (mode == TprChartMode.pulse) {
      _drawNormalBand(canvas, leftMargin, chartWidth, topMargin, chartHeight, 60, 100, minY, maxY);
    } else if (mode == TprChartMode.respiration) {
      _drawNormalBand(canvas, leftMargin, chartWidth, topMargin, chartHeight, 12, 20, minY, maxY);
    }

    // Coordinates mapper
    double mapY(double val, double min, double max) {
      final clamped = val.clamp(min, max);
      final ratio = (clamped - min) / (max - min);
      return topMargin + chartHeight * (1.0 - ratio);
    }

    // 2. Draw Curves & Glyphs
    // Draw Temperature
    if (mode == TprChartMode.combined || mode == TprChartMode.temperature) {
      final tempMin = mode == TprChartMode.combined ? 95.0 : minY;
      final tempMax = mode == TprChartMode.combined ? 106.0 : maxY;
      _drawSeries(
        canvas: canvas,
        data: data,
        key: 'temperature',
        minVal: tempMin,
        maxVal: tempMax,
        leftMargin: leftMargin,
        stepX: stepX,
        mapY: mapY,
        color: const Color(0xFFE11D48),
        glyph: _GlyphType.triangle,
      );
    }

    // Draw Pulse
    if (mode == TprChartMode.combined || mode == TprChartMode.pulse) {
      final pulseMin = mode == TprChartMode.combined ? 40.0 : minY;
      final pulseMax = mode == TprChartMode.combined ? 160.0 : maxY;
      _drawSeries(
        canvas: canvas,
        data: data,
        key: 'pulse',
        minVal: pulseMin,
        maxVal: pulseMax,
        leftMargin: leftMargin,
        stepX: stepX,
        mapY: mapY,
        color: const Color(0xFF2563EB),
        glyph: _GlyphType.circle,
      );
    }

    // Draw Respiration
    if (mode == TprChartMode.combined || mode == TprChartMode.respiration) {
      final respMin = mode == TprChartMode.combined ? 8.0 : minY;
      final respMax = mode == TprChartMode.combined ? 35.0 : maxY;
      _drawSeries(
        canvas: canvas,
        data: data,
        key: 'respiratory_rate',
        minVal: respMin,
        maxVal: respMax,
        leftMargin: leftMargin,
        stepX: stepX,
        mapY: mapY,
        color: const Color(0xFF059669),
        glyph: _GlyphType.square,
      );
    }

    // Draw Blood Pressure (Systolic & Diastolic error-bar/band)
    if (mode == TprChartMode.combined || mode == TprChartMode.bloodPressure) {
      final bpMin = mode == TprChartMode.combined ? 40.0 : minY;
      final bpMax = mode == TprChartMode.combined ? 200.0 : maxY;

      final bpBarPaint = Paint()
        ..color = const Color(0xFF7C3AED).withValues(alpha: 0.3)
        ..strokeWidth = 3.5;

      final sysPaint = Paint()
        ..color = const Color(0xFF7C3AED)
        ..style = PaintingStyle.fill;

      final diaPaint = Paint()
        ..color = const Color(0xFFA855F7)
        ..style = PaintingStyle.fill;

      final linePaint = Paint()
        ..color = const Color(0xFF7C3AED)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      final Path sysPath = Path();
      bool sysStarted = false;

      for (int i = 0; i < count; i++) {
        final x = leftMargin + (stepX * i);
        final sysVal = double.tryParse(data[i]['blood_pressure_systolic']?.toString() ?? '');
        final diaVal = double.tryParse(data[i]['blood_pressure_diastolic']?.toString() ?? '');

        if (sysVal != null && diaVal != null) {
          final sysY = mapY(sysVal, bpMin, bpMax);
          final diaY = mapY(diaVal, bpMin, bpMax);

          // Vertical band between sys & dia
          canvas.drawLine(Offset(x, sysY), Offset(x, diaY), bpBarPaint);

          // Glyphs
          canvas.drawCircle(Offset(x, sysY), 3.5, sysPaint);
          canvas.drawCircle(Offset(x, diaY), 3.5, diaPaint);

          if (!sysStarted) {
            sysPath.moveTo(x, sysY);
            sysStarted = true;
          } else {
            sysPath.lineTo(x, sysY);
          }
        }
      }
      if (sysStarted) {
        canvas.drawPath(sysPath, linePaint);
      }
    }

    // Draw Hover Cursor Guideline
    if (hoveredIndex != null && hoveredIndex! < count) {
      final x = leftMargin + (stepX * hoveredIndex!);
      final hoverLinePaint = Paint()
        ..color = AppTheme.primaryColor
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, topMargin), Offset(x, topMargin + chartHeight), hoverLinePaint);
    }
  }

  void _drawNormalBand(
    Canvas canvas,
    double left,
    double width,
    double top,
    double height,
    double bandMin,
    double bandMax,
    double minY,
    double maxY,
  ) {
    final yTop = top + height * (1.0 - (bandMax - minY) / (maxY - minY));
    final yBottom = top + height * (1.0 - (bandMin - minY) / (maxY - minY));

    final bandPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTRB(left, yTop, left + width, yBottom), bandPaint);
  }

  void _drawSeries({
    required Canvas canvas,
    required List<Map<String, dynamic>> data,
    required String key,
    required double minVal,
    required double maxVal,
    required double leftMargin,
    required double stepX,
    required Function(double, double, double) mapY,
    required Color color,
    required _GlyphType glyph,
  }) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final glyphPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();
    bool started = false;

    for (int i = 0; i < data.length; i++) {
      final x = leftMargin + (stepX * i);
      final raw = double.tryParse(data[i][key]?.toString() ?? '');
      if (raw != null) {
        final y = mapY(raw, minVal, maxVal);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }

        // Draw Point Glyph
        if (glyph == _GlyphType.triangle) {
          final Path tri = Path()
            ..moveTo(x, y - 5)
            ..lineTo(x - 4.5, y + 4)
            ..lineTo(x + 4.5, y + 4)
            ..close();
          canvas.drawPath(tri, glyphPaint);
        } else if (glyph == _GlyphType.square) {
          canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 7, height: 7), glyphPaint);
        } else {
          canvas.drawCircle(Offset(x, y), 4.0, glyphPaint);
        }
      }
    }

    if (started) {
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClinicalTprPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.mode != mode ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

enum _GlyphType { circle, triangle, square }
