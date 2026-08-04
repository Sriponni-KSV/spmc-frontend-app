import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

class VitalsChart extends StatefulWidget {
  final List<Map<String, dynamic>> vitalsHistory;
  final List<String>? allowedTypes;

  const VitalsChart({
    Key? key,
    required this.vitalsHistory,
    this.allowedTypes,
  }) : super(key: key);

  @override
  State<VitalsChart> createState() => _VitalsChartState();
}

class _VitalsChartState extends State<VitalsChart> {
  late String _selectedVitalType;
  late final List<String> _vitalTypes;

  @override
  void initState() {
    super.initState();
    final defaultTypes = [
      'Blood Pressure',
      'Pulse / Heart Rate',
      'SpO2',
      'Temperature',
      'Sugar Level',
      'Respiratory Rate',
    ];
    if (widget.allowedTypes != null) {
      _vitalTypes = defaultTypes.where((type) => widget.allowedTypes!.contains(type)).toList();
    } else {
      _vitalTypes = defaultTypes;
    }

    if (_vitalTypes.contains('Blood Pressure')) {
      _selectedVitalType = 'Blood Pressure';
    } else if (_vitalTypes.isNotEmpty) {
      _selectedVitalType = _vitalTypes.first;
    } else {
      _selectedVitalType = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vitalsHistory.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_outlined, color: AppTheme.textMutedColor, size: 32),
            SizedBox(height: 8),
            Text(
              'No Vitals History Available',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Limit to last 10 entries to keep chart readable
    final visibleVitals = widget.vitalsHistory.length > 10
        ? widget.vitalsHistory.sublist(widget.vitalsHistory.length - 10)
        : widget.vitalsHistory;

    List<double> series1 = [];
    List<double>? series2;
    List<String> dates = [];
    double minY = 0;
    double maxY = 100;
    String unit = '';
    Color color1 = AppTheme.primaryColor;
    Color? color2;

    for (var v in visibleVitals) {
      final dateStr = v['created_at'] ?? v['created_date'];
      String formattedDate = '';
      if (dateStr != null) {
        try {
          final parsed = DateTime.parse(dateStr).toLocal();
          formattedDate = DateFormat('dd/MM hh:mm').format(parsed);
        } catch (_) {
          formattedDate = dateStr.toString();
        }
      }
      dates.add(formattedDate);

      if (_selectedVitalType == 'Blood Pressure') {
        final sys = double.tryParse(v['blood_pressure_systolic']?.toString() ?? '') ?? 0;
        final dia = double.tryParse(v['blood_pressure_diastolic']?.toString() ?? '') ?? 0;
        series1.add(sys);
        series2 ??= [];
        series2.add(dia);
        minY = 40;
        maxY = 220;
        unit = 'mmHg';
        color1 = AppTheme.primaryColor; // Blue
        color2 = AppTheme.secondaryColor; // Green
      } else if (_selectedVitalType == 'Pulse / Heart Rate') {
        final pulse = double.tryParse(v['pulse']?.toString() ?? '') ?? 0;
        series1.add(pulse);
        minY = 40;
        maxY = 180;
        unit = 'bpm';
        color1 = const Color(0xFFDD6B20); // Orange
      } else if (_selectedVitalType == 'SpO2') {
        final spo2 = double.tryParse(v['spo2']?.toString() ?? '') ?? 0;
        series1.add(spo2);
        minY = 70;
        maxY = 100;
        unit = '%';
        color1 = const Color(0xFF0D9488); // Teal
      } else if (_selectedVitalType == 'Temperature') {
        final temp = double.tryParse(v['temperature']?.toString() ?? '') ?? 0;
        series1.add(temp);
        minY = 94;
        maxY = 108;
        unit = '°F';
        color1 = AppTheme.logoRed; // Red
      } else if (_selectedVitalType == 'Sugar Level') {
        final sugar = double.tryParse(v['sugar_level']?.toString() ?? '') ?? 0;
        series1.add(sugar);
        minY = 20;
        maxY = 400;
        unit = 'mg/dL';
        color1 = const Color(0xFF8B5CF6); // Purple
      } else if (_selectedVitalType == 'Respiratory Rate') {
        final rr = double.tryParse(v['respiratory_rate']?.toString() ?? '') ?? 0;
        series1.add(rr);
        minY = 8;
        maxY = 40;
        unit = 'breaths/min';
        color1 = const Color(0xFF475569); // Slate
      }
    }

    // Filter out zeros/invalid values if any to set better limits, or make range adapt to values
    double localMax1 = series1.isNotEmpty ? series1.reduce((a, b) => a > b ? a : b) : 0;
    double localMax2 = series2 != null && series2.isNotEmpty ? series2.reduce((a, b) => a > b ? a : b) : 0;
    double maxVal = localMax1 > localMax2 ? localMax1 : localMax2;

    double localMin1 = series1.isNotEmpty ? series1.reduce((a, b) => a < b ? a : b) : 999;
    double localMin2 = series2 != null && series2.isNotEmpty ? series2.reduce((a, b) => a < b ? a : b) : 999;
    double minVal = localMin1 < localMin2 ? localMin1 : localMin2;

    if (maxVal > 0) {
      if (maxVal > maxY) {
        maxY = maxVal + 10;
      }
      if (minVal < minY && minVal > 0) {
        minY = minVal - 10;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.8)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Vitals History & Trends',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              if (_vitalTypes.isNotEmpty)
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVitalType,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondaryColor, size: 20),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                        fontFamily: AppTheme.fontFamily,
                      ),
                      items: _vitalTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedVitalType = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Legend / Unit Label
          Row(
            children: [
              Text(
                'Unit: $unit',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const Spacer(),
              if (_selectedVitalType == 'Blood Pressure') ...[
                _buildLegendItem('Systolic', AppTheme.primaryColor),
                const SizedBox(width: 12),
                _buildLegendItem('Diastolic', AppTheme.secondaryColor),
              ] else ...[
                _buildLegendItem('Value', color1),
              ]
            ],
          ),
          const SizedBox(height: 12),
          // Chart Graphic
          Container(
            height: 180,
            padding: const EdgeInsets.only(top: 10, right: 10, bottom: 20),
            child: CustomPaint(
              size: Size.infinite,
              painter: VitalsChartPainter(
                data: series1,
                data2: series2,
                dates: dates,
                minY: minY,
                maxY: maxY,
                color1: color1,
                color2: color2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class VitalsChartPainter extends CustomPainter {
  final List<double> data;
  final List<double>? data2;
  final List<String> dates;
  final double minY;
  final double maxY;
  final Color color1;
  final Color? color2;

  VitalsChartPainter({
    required this.data,
    required this.data2,
    required this.dates,
    required this.minY,
    required this.maxY,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Paints
    final gridPaint = Paint()
      ..color = AppTheme.borderColor.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final labelStyle = const TextStyle(
      color: AppTheme.textSecondaryColor,
      fontSize: 9,
      fontWeight: FontWeight.w500,
      fontFamily: AppTheme.fontFamily,
    );

    // Draw horizontal grid lines and Y-axis labels
    const int gridRows = 4;
    for (int i = 0; i <= gridRows; i++) {
      final double ratio = i / gridRows;
      final double y = height * (1 - ratio);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);

      final double val = minY + (maxY - minY) * ratio;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: val.toStringAsFixed(0), style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-25, y - (tp.height / 2)));
    }

    final double stepX = data.length > 1 ? width / (data.length - 1) : width;

    // Helper coordinates
    double getX(int index) => index * stepX;
    double getY(double value) {
      if (value < minY) value = minY;
      if (value > maxY) value = maxY;
      final double ratio = (value - minY) / (maxY - minY);
      return height - (ratio * height);
    }

    // Function to draw a series line & shadow
    void drawSeries(List<double> seriesData, Color col, {bool isSecondary = false}) {
      if (seriesData.length == 1) {
        // Just draw a single dot
        final offset = Offset(getX(0), getY(seriesData[0]));
        canvas.drawCircle(offset, 4, Paint()..color = col);
        return;
      }

      final path = Path();
      final fillPath = Path();

      path.moveTo(getX(0), getY(seriesData[0]));
      fillPath.moveTo(getX(0), height);
      fillPath.lineTo(getX(0), getY(seriesData[0]));

      for (int i = 0; i < seriesData.length - 1; i++) {
        final x1 = getX(i);
        final y1 = getY(seriesData[i]);
        final x2 = getX(i + 1);
        final y2 = getY(seriesData[i + 1]);

        final cx1 = x1 + (x2 - x1) / 2;
        final cy1 = y1;
        final cx2 = x1 + (x2 - x1) / 2;
        final cy2 = y2;

        path.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
        fillPath.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
      }

      fillPath.lineTo(getX(seriesData.length - 1), height);
      fillPath.close();

      // Shading under the line
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            col.withOpacity(isSecondary ? 0.1 : 0.15),
            col.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);

      // Line itself
      final linePaint = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);

      // Draw markers and numeric labels for points
      final pointPaint = Paint()
        ..color = col
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      for (int i = 0; i < seriesData.length; i++) {
        final offset = Offset(getX(i), getY(seriesData[i]));
        canvas.drawCircle(offset, 4, borderPaint);
        canvas.drawCircle(offset, 2.5, pointPaint);

        // Numeric value label above/below point
        if (seriesData[i] > 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: seriesData[i].toStringAsFixed(0),
              style: TextStyle(
                color: col,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            textDirection: ui.TextDirection.ltr,
          )..layout();
          final double labelYOffset = isSecondary ? 10.0 : -14.0;
          tp.paint(canvas, Offset(offset.dx - (tp.width / 2), offset.dy + labelYOffset));
        }
      }
    }

    // Draw main series
    drawSeries(data, color1);

    // Draw secondary series if provided
    if (data2 != null && color2 != null) {
      drawSeries(data2!, color2!, isSecondary: true);
    }

    // Draw X-axis dates
    for (int i = 0; i < dates.length; i++) {
      if (dates.length > 5 && i % 2 != 0) continue; // Decimate labels if too many to prevent overlap
      final x = getX(i);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: dates[i], style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - (tp.width / 2), height + 4));
    }
  }

  @override
  bool shouldRepaint(covariant VitalsChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.data2 != data2 ||
        oldDelegate.dates != dates ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2;
  }
}
