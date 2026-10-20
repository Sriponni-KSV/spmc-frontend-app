import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../screens/ot_management.dart';
import '../controllers/ot_controller.dart';
import 'who_surgical_safety_checklist_widget.dart';
import 'pac_assessment_dialog.dart';

class OtTheatreCalendarWidget extends StatefulWidget {
  final List<OtCase> otCases;
  final bool isMobile;
  final String currentUser;
  final Function(OtCase selectedCase)? onSelectCase;
  final VoidCallback? onScheduleNew;
  final VoidCallback? onRefresh;

  const OtTheatreCalendarWidget({
    Key? key,
    required this.otCases,
    required this.isMobile,
    required this.currentUser,
    this.onSelectCase,
    this.onScheduleNew,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<OtTheatreCalendarWidget> createState() => _OtTheatreCalendarWidgetState();
}

class _OtTheatreCalendarWidgetState extends State<OtTheatreCalendarWidget> {
  DateTime _selectedDate = DateTime.now();
  final OtController _otController = OtController();
  List<Map<String, dynamic>> _theatres = [];
  bool _isLoadingTheatres = false;

  // Standard theatres fallback if API is loading
  final List<Map<String, String>> _defaultTheatres = [
    {'code': 'OT 1', 'name': 'OT 1 - Major OT (General & Lap)', 'type': 'Major'},
    {'code': 'OT 2', 'name': 'OT 2 - Ortho & Trauma', 'type': 'Major'},
    {'code': 'OT 3', 'name': 'OT 3 - Minor & Day Surgery', 'type': 'Minor'},
    {'code': 'OT 4', 'name': 'OT 4 - Ophthalmology & ENT', 'type': 'Speciality'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTheatres();
  }

  Future<void> _loadTheatres() async {
    setState(() => _isLoadingTheatres = true);
    try {
      final theatres = await _otController.fetchTheatres();
      if (mounted) {
        setState(() {
          _theatres = theatres;
          _isLoadingTheatres = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTheatres = false);
      }
    }
  }

  List<String> get _theatreKeys {
    if (_theatres.isNotEmpty) {
      return _theatres.map((t) => t['theatre_code']?.toString() ?? t['theatre_name']?.toString() ?? 'OT 1').toList();
    }
    return _defaultTheatres.map((t) => t['code']!).toList();
  }

  String _normalizeCode(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _getTheatreDisplayName(String key) {
    final keyNorm = _normalizeCode(key);
    if (_theatres.isNotEmpty) {
      final match = _theatres.firstWhere(
        (t) {
          final tCodeNorm = _normalizeCode(t['theatre_code']?.toString() ?? '');
          final tNameNorm = _normalizeCode(t['theatre_name']?.toString() ?? '');
          return tCodeNorm == keyNorm || tNameNorm == keyNorm || t['theatre_code'] == key || t['theatre_name'] == key;
        },
        orElse: () => {'theatre_name': key},
      );
      return match['theatre_name'] ?? key;
    }
    final match = _defaultTheatres.firstWhere(
      (t) {
        final codeNorm = _normalizeCode(t['code'] ?? '');
        return codeNorm == keyNorm || t['code'] == key;
      },
      orElse: () => {'name': key},
    );
    return match['name']!;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<OtCase> get _casesForSelectedDay {
    return widget.otCases.where((c) {
      final date = c.scheduledStartTime ?? c.surgeryDateTime;
      if (date == null) return false;
      return _isSameDay(date, _selectedDate);
    }).toList();
  }

  /// Detect conflicts among day's cases
  Map<int, List<String>> _detectDayConflicts(List<OtCase> cases) {
    final Map<int, List<String>> conflictsMap = {};

    for (int i = 0; i < cases.length; i++) {
      for (int j = i + 1; j < cases.length; j++) {
        final a = cases[i];
        final b = cases[j];

        final startA = a.scheduledStartTime ?? a.surgeryDateTime;
        final endA = a.scheduledEndTime ?? (startA != null ? startA.add(Duration(minutes: a.estimatedDurationMinutes)) : null);

        final startB = b.scheduledStartTime ?? b.surgeryDateTime;
        final endB = b.scheduledEndTime ?? (startB != null ? startB.add(Duration(minutes: b.estimatedDurationMinutes)) : null);

        if (startA == null || endA == null || startB == null || endB == null) continue;

        // Check time overlap: (startA < endB) && (endA > startB)
        final overlaps = startA.isBefore(endB) && endA.isAfter(startB);
        if (!overlaps) continue;

        // 1. Same Theatre overlap
        final roomA = _normalizeCode(a.otRoom ?? '');
        final roomB = _normalizeCode(b.otRoom ?? '');
        if (roomA.isNotEmpty && roomB.isNotEmpty && (roomA == roomB || roomA.contains(roomB) || roomB.contains(roomA))) {
          final msgA = 'Theatre Overlap with ${b.id} (${b.patientName})';
          final msgB = 'Theatre Overlap with ${a.id} (${a.patientName})';
          if (a.dbId != null) conflictsMap.putIfAbsent(a.dbId!, () => []).add(msgA);
          if (b.dbId != null) conflictsMap.putIfAbsent(b.dbId!, () => []).add(msgB);
        }

        // 2. Same Lead Surgeon overlap
        final surgA = (a.leadSurgeon ?? a.surgeon ?? '').toLowerCase().trim();
        final surgB = (b.leadSurgeon ?? b.surgeon ?? '').toLowerCase().trim();
        if (surgA.isNotEmpty && surgB.isNotEmpty && surgA == surgB) {
          final msgA = 'Surgeon ${a.leadSurgeon} double-booked with ${b.id} in ${b.otRoom}';
          final msgB = 'Surgeon ${b.leadSurgeon} double-booked with ${a.id} in ${a.otRoom}';
          if (a.dbId != null) conflictsMap.putIfAbsent(a.dbId!, () => []).add(msgA);
          if (b.dbId != null) conflictsMap.putIfAbsent(b.dbId!, () => []).add(msgB);
        }

        // 3. Same Anaesthetist overlap
        final anaestA = (a.anaesthetist ?? '').toLowerCase().trim();
        final anaestB = (b.anaesthetist ?? '').toLowerCase().trim();
        if (anaestA.isNotEmpty && anaestB.isNotEmpty && anaestA == anaestB) {
          final msgA = 'Anaesthetist ${a.anaesthetist} double-booked with ${b.id} in ${b.otRoom}';
          final msgB = 'Anaesthetist ${b.anaesthetist} double-booked with ${a.id} in ${a.otRoom}';
          if (a.dbId != null) conflictsMap.putIfAbsent(a.dbId!, () => []).add(msgA);
          if (b.dbId != null) conflictsMap.putIfAbsent(b.dbId!, () => []).add(msgB);
        }
      }
    }

    return conflictsMap;
  }

  bool _matchesTheatre(OtCase c, String theatreKey) {
    final room = c.otRoom ?? '';
    final roomNorm = _normalizeCode(room);
    final keyNorm = _normalizeCode(theatreKey);

    // 1. Direct ID match if available in _theatres
    if (c.theatreId != null && _theatres.isNotEmpty) {
      final matchingTheatre = _theatres.firstWhere(
        (t) => t['id'] == c.theatreId,
        orElse: () => {},
      );
      if (matchingTheatre.isNotEmpty) {
        final tCodeNorm = _normalizeCode(matchingTheatre['theatre_code']?.toString() ?? '');
        final tNameNorm = _normalizeCode(matchingTheatre['theatre_name']?.toString() ?? '');
        if (tCodeNorm == keyNorm || tNameNorm == keyNorm || tCodeNorm.contains(keyNorm) || keyNorm.contains(tCodeNorm)) {
          return true;
        }
      }
    }

    if (roomNorm.isEmpty && keyNorm.isEmpty) return false;
    if (roomNorm.isEmpty || keyNorm.isEmpty) return false;

    // 2. Normalized code match (e.g. 'ot2' == 'ot2' matches 'OT 2' and 'OT-2')
    if (roomNorm == keyNorm || roomNorm.contains(keyNorm) || keyNorm.contains(roomNorm)) {
      return true;
    }

    // 3. Match against theatre name if theatreKey matches code or name in _theatres
    if (_theatres.isNotEmpty) {
      for (final t in _theatres) {
        final tCodeNorm = _normalizeCode(t['theatre_code']?.toString() ?? '');
        final tNameNorm = _normalizeCode(t['theatre_name']?.toString() ?? '');
        if (tCodeNorm == keyNorm || tNameNorm == keyNorm) {
          if (roomNorm == tCodeNorm || roomNorm == tNameNorm || tNameNorm.contains(roomNorm) || roomNorm.contains(tCodeNorm)) {
            return true;
          }
        }
      }
    }

    // 4. Also check default theatres
    for (final t in _defaultTheatres) {
      final tCodeNorm = _normalizeCode(t['code'] ?? '');
      final tNameNorm = _normalizeCode(t['name'] ?? '');
      if (tCodeNorm == keyNorm || tNameNorm == keyNorm) {
        if (roomNorm == tCodeNorm || roomNorm == tNameNorm || tNameNorm.contains(roomNorm) || roomNorm.contains(tCodeNorm)) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dayCases = _casesForSelectedDay;
    final conflictsMap = _detectDayConflicts(dayCases);
    final totalConflicts = conflictsMap.values.fold<int>(0, (sum, list) => sum + list.length);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigation & Action Header
          _buildHeader(totalConflicts),

          // Conflict Alert Banner (if conflicts exist)
          if (totalConflicts > 0) _buildConflictBanner(totalConflicts, conflictsMap),

          // Main Multi-Theatre Timeline Grid
          Expanded(
            child: widget.isMobile
                ? _buildMobileTimeline(dayCases, conflictsMap)
                : _buildDesktopTimeline(dayCases, conflictsMap),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalConflicts) {
    final dateFormat = widget.isMobile
        ? DateFormat('EEE, d MMM yyyy')
        : DateFormat('EEEE, dd MMMM yyyy');
    final formattedDate = dateFormat.format(_selectedDate);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 10 : 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 10,
        children: [
          // Date Navigator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_left, color: AppTheme.primaryColor, size: 20),
                onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                tooltip: 'Previous Day',
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 8 : 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: widget.isMobile ? 12 : 13,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_right, color: AppTheme.primaryColor, size: 20),
                onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                tooltip: 'Next Day',
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(40, 32),
                ),
                onPressed: () => setState(() => _selectedDate = DateTime.now()),
                child: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),

          // Right action bar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Conflict Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: totalConflicts == 0
                      ? AppTheme.secondaryColor.withOpacity(0.12)
                      : AppTheme.dangerColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: totalConflicts == 0
                        ? AppTheme.secondaryColor.withOpacity(0.3)
                        : AppTheme.dangerColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      totalConflicts == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: totalConflicts == 0 ? AppTheme.secondaryColor : AppTheme.dangerColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      totalConflicts == 0 ? 'No Scheduling Conflicts' : '$totalConflicts Conflict(s) Detected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: totalConflicts == 0 ? AppTheme.secondaryColor : AppTheme.dangerColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Refresh Button
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: _isLoadingTheatres
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, color: Color(0xFF64748B), size: 18),
                onPressed: () {
                  _loadTheatres();
                  if (widget.onRefresh != null) widget.onRefresh!();
                },
                tooltip: 'Refresh Timeline',
              ),

              if (widget.onScheduleNew != null) ...[
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: widget.onScheduleNew,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Book Surgery', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictBanner(int totalConflicts, Map<int, List<String>> conflictsMap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border(bottom: BorderSide(color: AppTheme.dangerColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ATTENTION: $totalConflicts scheduling collision(s) detected across theatres on this date. Review highlighted red slots to prevent double-booking surgeons or operating rooms.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.dangerColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DESKTOP MULTI-THEATRE TIMELINE
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopTimeline(List<OtCase> dayCases, Map<int, List<String>> conflictsMap) {
    final theatres = _theatreKeys;
    const hourHeight = 90.0;
    const startHour = 8;
    const endHour = 20;
    final totalHours = endHour - startHour;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Time Axis Header & Column
        Container(
          width: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border(right: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Column(
            children: [
              // Corner Cell
              Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                alignment: Alignment.center,
                child: const Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
              ),
              // Time Hour Markers
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: List.generate(totalHours, (index) {
                      final hour = startHour + index;
                      final timeStr = DateFormat('hh:mm a').format(DateTime(2026, 1, 1, hour));
                      return Container(
                        height: hourHeight,
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          timeStr,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Theatre Columns
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (theatres.length * 280.0).clamp(MediaQuery.of(context).size.width - 200, 2000.0),
              child: Column(
                children: [
                  // Theatre Headers
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                    ),
                    child: Row(
                      children: theatres.map((tKey) {
                        final displayName = _getTheatreDisplayName(tKey);
                        final theatreCases = dayCases.where((c) => _matchesTheatre(c, tKey)).toList();
                        return Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: AppTheme.borderColor)),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(Icons.meeting_room_outlined, size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${theatreCases.length} booked',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Theatres Timelines Grid
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        height: totalHours * hourHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: theatres.map((tKey) {
                            final theatreCases = dayCases.where((c) => _matchesTheatre(c, tKey)).toList();

                            return Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(right: BorderSide(color: AppTheme.borderColor)),
                                ),
                                child: Stack(
                                  children: [
                                    // Background Hour Grid Lines
                                    Column(
                                      children: List.generate(totalHours, (index) {
                                        return Container(
                                          height: hourHeight,
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
                                          ),
                                        );
                                      }),
                                    ),

                                    // Positioned Surgery Cards
                                    ...theatreCases.map((c) {
                                      final start = c.scheduledStartTime ?? c.surgeryDateTime;
                                      if (start == null) return const SizedBox.shrink();

                                      final duration = c.estimatedDurationMinutes > 0 ? c.estimatedDurationMinutes : 90;
                                      final startMinutes = (start.hour - startHour) * 60 + start.minute;
                                      final top = (startMinutes / 60.0) * hourHeight;
                                      final height = (duration / 60.0) * hourHeight;

                                      final hasConflict = c.dbId != null && conflictsMap.containsKey(c.dbId);
                                      final conflictMsgs = c.dbId != null ? (conflictsMap[c.dbId!] ?? []) : <String>[];

                                      return Positioned(
                                        top: top.clamp(0.0, totalHours * hourHeight - 30),
                                        left: 6,
                                        right: 6,
                                        height: height.clamp(50.0, totalHours * hourHeight),
                                        child: _buildSurgeryBlock(c, hasConflict, conflictMsgs),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MOBILE TIMELINE VIEW
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileTimeline(List<OtCase> dayCases, Map<int, List<String>> conflictsMap) {
    if (dayCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No surgeries scheduled for this date.', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Use the button above to book a new surgical slot.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    final theatres = _theatreKeys;
    final matchedCases = <OtCase>{};
    final List<Widget> theatreCards = [];

    for (final tKey in theatres) {
      final theatreCases = dayCases.where((c) => _matchesTheatre(c, tKey)).toList();
      if (theatreCases.isNotEmpty) {
        matchedCases.addAll(theatreCases);
        final displayName = _getTheatreDisplayName(tKey);
        theatreCards.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${theatreCases.length} case(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: theatreCases.map((c) {
                      final hasConflict = c.dbId != null && conflictsMap.containsKey(c.dbId);
                      final conflictMsgs = c.dbId != null ? (conflictsMap[c.dbId!] ?? []) : <String>[];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        height: 120,
                        child: _buildSurgeryBlock(c, hasConflict, conflictMsgs),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Any cases not matched to the configured theatre list
    final unassignedCases = dayCases.where((c) => !matchedCases.contains(c)).toList();
    if (unassignedCases.isNotEmpty) {
      theatreCards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.meeting_room_outlined, color: Color(0xFFD97706), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scheduled Cases (${unassignedCases.first.otRoom ?? "OT Slot"})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${unassignedCases.length} case(s)', style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: unassignedCases.map((c) {
                    final hasConflict = c.dbId != null && conflictsMap.containsKey(c.dbId);
                    final conflictMsgs = c.dbId != null ? (conflictsMap[c.dbId!] ?? []) : <String>[];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: 120,
                      child: _buildSurgeryBlock(c, hasConflict, conflictMsgs),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (theatreCards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No surgeries scheduled for this date.', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Use the button above to book a new surgical slot.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: theatreCards,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SURGERY CARD BLOCK
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSurgeryBlock(OtCase c, bool hasConflict, List<String> conflictMsgs) {
    final start = c.scheduledStartTime ?? c.surgeryDateTime;
    final end = c.scheduledEndTime ?? (start != null ? start.add(Duration(minutes: c.estimatedDurationMinutes)) : null);

    final timeStr = start != null && end != null
        ? '${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}'
        : 'Scheduled Slot';

    final isEmergency = (c.priority ?? '').toLowerCase() == 'emergency';

    return InkWell(
      onTap: () => _showCaseActionModal(c, hasConflict, conflictMsgs),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasConflict ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasConflict ? AppTheme.dangerColor : AppTheme.primaryColor.withOpacity(0.3),
            width: hasConflict ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (hasConflict ? AppTheme.dangerColor : Colors.black).withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Time & Priority
            Row(
              children: [
                Icon(
                  hasConflict ? Icons.warning_amber_rounded : Icons.access_time,
                  size: 13,
                  color: hasConflict ? AppTheme.dangerColor : AppTheme.primaryColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasConflict ? AppTheme.dangerColor : AppTheme.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('EMERGENCY', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),

            // Middle: Patient Name & Procedure
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.patientName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  c.surgeryType ?? c.diagnosis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // Bottom Badges: Lead Surgeon & PAC Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Surgeon: ${c.leadSurgeon ?? c.surgeon ?? "TBD"}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildPacChip(c.pacStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacChip(String pacStatus) {
    Color bg;
    Color fg;
    String label;

    switch (pacStatus) {
      case 'Cleared':
        bg = AppTheme.secondaryColor.withOpacity(0.12);
        fg = AppTheme.secondaryColor;
        label = 'PAC OK';
        break;
      case 'High Risk Clearance':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'PAC HIGH';
        break;
      case 'Deferred':
      case 'Rejected':
        bg = AppTheme.dangerColor.withOpacity(0.12);
        fg = AppTheme.dangerColor;
        label = 'PAC NO';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'PAC PEND';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CASE ACTIONS MODAL
  // ─────────────────────────────────────────────────────────────────────────────
  void _showCaseActionModal(OtCase c, bool hasConflict, List<String> conflictMsgs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Case header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                    child: Text(c.patientName.isNotEmpty ? c.patientName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${c.id} • ${c.otRoom ?? "Theatre TBD"} • ${c.surgeryType ?? c.diagnosis}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),

              // Conflict warnings
              if (hasConflict && conflictMsgs.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.dangerColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: AppTheme.dangerColor, size: 16),
                          SizedBox(width: 6),
                          Text('Scheduling Conflicts Detected:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.dangerColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...conflictMsgs.map((m) => Text('• $m', style: const TextStyle(fontSize: 11, color: AppTheme.dangerColor))).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Complete Team Allocation Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Surgical Team Allocation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    _buildTeamRow('Lead Surgeon', c.leadSurgeon ?? c.surgeon ?? 'Not Assigned'),
                    _buildTeamRow('Assistant Surgeon', c.assistantSurgeon ?? 'Not Assigned'),
                    _buildTeamRow('Anaesthetist', c.anaesthetist ?? 'Not Assigned'),
                    _buildTeamRow('Scrub Nurse', c.scrubNurse ?? 'Not Assigned'),
                    _buildTeamRow('Circulating Nurse', c.circulatingNurse ?? 'Not Assigned'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPacDialog(c);
                      },
                      icon: const Icon(Icons.medical_services_outlined, size: 16),
                      label: const Text('PAC Assessment'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showWhoChecklistModal(c);
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text('WHO Checklist'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (widget.onSelectCase != null) {
                          widget.onSelectCase!(c);
                        }
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Open Workflow'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamRow(String role, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(role, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showPacDialog(OtCase c) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PacAssessmentDialog(
        otCase: c,
        isMobile: widget.isMobile,
        currentUser: widget.currentUser,
        onPacUpdated: (updatedCase) {
          if (widget.onRefresh != null) widget.onRefresh!();
        },
      ),
    );
  }

  void _showWhoChecklistModal(OtCase c) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: EdgeInsets.all(widget.isMobile ? 12 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 820,
            maxHeight: MediaQuery.of(context).size.height * (widget.isMobile ? 0.88 : 0.85),
          ),
          child: WhoSurgicalSafetyChecklistWidget(
            otCase: c,
            isMobile: widget.isMobile,
            isPopup: true,
            currentUser: widget.currentUser,
            onChecklistUpdated: (updatedCase) {
              if (widget.onRefresh != null) widget.onRefresh!();
            },
          ),
        ),
      ),
    );
  }
}
