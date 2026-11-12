import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../screens/ot_management.dart';
import '../controllers/ot_controller.dart';
import 'who_surgical_safety_checklist_widget.dart';
import 'pac_assessment_dialog.dart';

enum OtCalendarViewMode { daily, weekly, monthly }

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
  OtCalendarViewMode _viewMode = OtCalendarViewMode.daily;
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

  List<OtCase> _getCasesForDay(DateTime date) {
    return widget.otCases.where((c) {
      final d = c.scheduledStartTime ?? c.surgeryDateTime;
      if (d == null) return false;
      return _isSameDay(d, date);
    }).toList();
  }

  List<OtCase> get _casesForSelectedDay => _getCasesForDay(_selectedDate);

  DateTime _startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
  }

  List<DateTime> _getDaysOfWeek(DateTime date) {
    final monday = _startOfWeek(date);
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  List<DateTime?> _getDaysOfMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1;
    final List<DateTime?> cells = [];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(null);
    }
    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(date.year, date.month, day));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  void _goToPrevious() {
    setState(() {
      switch (_viewMode) {
        case OtCalendarViewMode.daily:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case OtCalendarViewMode.weekly:
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          break;
        case OtCalendarViewMode.monthly:
          final prevMonth = _selectedDate.month == 1 ? 12 : _selectedDate.month - 1;
          final prevYear = _selectedDate.month == 1 ? _selectedDate.year - 1 : _selectedDate.year;
          final daysInPrev = DateTime(prevYear, prevMonth + 1, 0).day;
          final newDay = _selectedDate.day > daysInPrev ? daysInPrev : _selectedDate.day;
          _selectedDate = DateTime(prevYear, prevMonth, newDay);
          break;
      }
    });
  }

  void _goToNext() {
    setState(() {
      switch (_viewMode) {
        case OtCalendarViewMode.daily:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case OtCalendarViewMode.weekly:
          _selectedDate = _selectedDate.add(const Duration(days: 7));
          break;
        case OtCalendarViewMode.monthly:
          final nextMonth = _selectedDate.month == 12 ? 1 : _selectedDate.month + 1;
          final nextYear = _selectedDate.month == 12 ? _selectedDate.year + 1 : _selectedDate.year;
          final daysInNext = DateTime(nextYear, nextMonth + 1, 0).day;
          final newDay = _selectedDate.day > daysInNext ? daysInNext : _selectedDate.day;
          _selectedDate = DateTime(nextYear, nextMonth, newDay);
          break;
      }
    });
  }

  String _getHeaderTitle() {
    switch (_viewMode) {
      case OtCalendarViewMode.daily:
        final dateFormat = widget.isMobile
            ? DateFormat('EEE, d MMM yyyy')
            : DateFormat('EEEE, dd MMMM yyyy');
        return dateFormat.format(_selectedDate);
      case OtCalendarViewMode.weekly:
        final days = _getDaysOfWeek(_selectedDate);
        final start = days.first;
        final end = days.last;
        if (start.month == end.month) {
          return '${DateFormat('d').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
        } else {
          return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
        }
      case OtCalendarViewMode.monthly:
        return DateFormat('MMMM yyyy').format(_selectedDate);
    }
  }

  String get _prevTooltip {
    switch (_viewMode) {
      case OtCalendarViewMode.daily:
        return 'Previous Day';
      case OtCalendarViewMode.weekly:
        return 'Previous Week';
      case OtCalendarViewMode.monthly:
        return 'Previous Month';
    }
  }

  String get _nextTooltip {
    switch (_viewMode) {
      case OtCalendarViewMode.daily:
        return 'Next Day';
      case OtCalendarViewMode.weekly:
        return 'Next Week';
      case OtCalendarViewMode.monthly:
        return 'Next Month';
    }
  }

  int _getWeekConflictsCount() {
    final days = _getDaysOfWeek(_selectedDate);
    int count = 0;
    for (final day in days) {
      final cases = _getCasesForDay(day);
      final conflicts = _detectDayConflicts(cases);
      count += conflicts.values.fold<int>(0, (sum, list) => sum + list.length);
    }
    return count;
  }

  int _getMonthConflictsCount() {
    final monthCases = widget.otCases.where((c) {
      final d = c.scheduledStartTime ?? c.surgeryDateTime;
      if (d == null) return false;
      return d.year == _selectedDate.year && d.month == _selectedDate.month;
    }).toList();
    final Map<int, List<OtCase>> dayMap = {};
    for (final c in monthCases) {
      final d = c.scheduledStartTime ?? c.surgeryDateTime!;
      dayMap.putIfAbsent(d.day, () => []).add(c);
    }
    int count = 0;
    for (final cases in dayMap.values) {
      final conflicts = _detectDayConflicts(cases);
      count += conflicts.values.fold<int>(0, (sum, list) => sum + list.length);
    }
    return count;
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

    int activeConflicts = 0;
    if (_viewMode == OtCalendarViewMode.daily) {
      activeConflicts = totalConflicts;
    } else if (_viewMode == OtCalendarViewMode.weekly) {
      activeConflicts = _getWeekConflictsCount();
    } else {
      activeConflicts = _getMonthConflictsCount();
    }

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
          _buildHeader(activeConflicts),

          // Conflict Alert Banner (if conflicts exist in daily view)
          if (totalConflicts > 0 && _viewMode == OtCalendarViewMode.daily)
            _buildConflictBanner(totalConflicts, conflictsMap),

          // Main View Switcher
          Expanded(
            child: _buildCurrentView(dayCases, conflictsMap),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView(List<OtCase> dayCases, Map<int, List<String>> conflictsMap) {
    switch (_viewMode) {
      case OtCalendarViewMode.daily:
        return widget.isMobile
            ? _buildMobileTimeline(dayCases, conflictsMap)
            : _buildDesktopTimeline(dayCases, conflictsMap);
      case OtCalendarViewMode.weekly:
        return _buildWeeklyView();
      case OtCalendarViewMode.monthly:
        return _buildMonthlyView();
    }
  }

  Widget _buildHeader(int activeConflicts) {
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
                onPressed: _goToPrevious,
                tooltip: _prevTooltip,
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
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
                        _getHeaderTitle(),
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
                onPressed: _goToNext,
                tooltip: _nextTooltip,
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

          // Center View Mode Toggle: Daily | Weekly | Monthly
          _buildViewModeToggle(),

          // Right action bar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Conflict Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: activeConflicts == 0
                      ? AppTheme.secondaryColor.withOpacity(0.12)
                      : AppTheme.dangerColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activeConflicts == 0
                        ? AppTheme.secondaryColor.withOpacity(0.3)
                        : AppTheme.dangerColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activeConflicts == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: activeConflicts == 0 ? AppTheme.secondaryColor : AppTheme.dangerColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeConflicts == 0 ? 'No Scheduling Conflicts' : '$activeConflicts Conflict(s) Detected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: activeConflicts == 0 ? AppTheme.secondaryColor : AppTheme.dangerColor,
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

  Widget _buildViewModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeTab('Daily', OtCalendarViewMode.daily, Icons.view_day_outlined),
          _buildViewModeTab('Weekly', OtCalendarViewMode.weekly, Icons.view_week_outlined),
          _buildViewModeTab('Monthly', OtCalendarViewMode.monthly, Icons.calendar_view_month_outlined),
        ],
      ),
    );
  }

  Widget _buildViewModeTab(String label, OtCalendarViewMode mode, IconData icon) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 8 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: widget.isMobile ? 12 : 14,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: widget.isMobile ? 11 : 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // WEEKLY VIEW
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildWeeklyView() {
    final days = _getDaysOfWeek(_selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100;

        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: days.map((day) {
            final dayCol = _buildWeeklyDayColumn(day);
            return isCompact ? SizedBox(width: 240, child: dayCol) : Expanded(child: dayCol);
          }).toList(),
        );

        if (isCompact) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SizedBox(
              height: constraints.maxHeight,
              child: content,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: content,
        );
      },
    );
  }

  Widget _buildWeeklyDayColumn(DateTime day) {
    final isSelected = _isSameDay(day, _selectedDate);
    final isToday = _isSameDay(day, DateTime.now());
    final dayCases = _getCasesForDay(day);
    final dayConflicts = _detectDayConflicts(dayCases);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.03) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          InkWell(
            onTap: () => setState(() => _selectedDate = day),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.12)
                    : (isToday ? AppTheme.secondaryColor.withOpacity(0.1) : const Color(0xFFF1F5F9)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEE').format(day).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : (isToday ? AppTheme.secondaryColor : const Color(0xFF475569)),
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('TODAY', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        icon: const Icon(Icons.schedule, size: 15, color: AppTheme.primaryColor),
                        tooltip: 'View Hour Timeline for this day',
                        onPressed: () {
                          setState(() {
                            _selectedDate = day;
                            _viewMode = OtCalendarViewMode.daily;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('d MMM').format(day),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: dayCases.isEmpty
                              ? Colors.grey.shade200
                              : AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${dayCases.length} ${dayCases.length == 1 ? "case" : "cases"}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: dayCases.isEmpty ? Colors.grey.shade600 : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Cases List
          Expanded(
            child: dayCases.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_outlined, size: 28, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text(
                            'No surgeries',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          if (widget.onScheduleNew != null) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                setState(() => _selectedDate = day);
                                widget.onScheduleNew!();
                              },
                              child: const Text(
                                '+ Book',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: dayCases.length,
                    itemBuilder: (context, index) {
                      final c = dayCases[index];
                      final hasConflict = c.dbId != null && dayConflicts.containsKey(c.dbId);
                      final conflictMsgs = c.dbId != null ? (dayConflicts[c.dbId!] ?? []) : <String>[];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: _buildWeeklyCaseCard(c, hasConflict, conflictMsgs),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCaseCard(OtCase c, bool hasConflict, List<String> conflictMsgs) {
    final start = c.scheduledStartTime ?? c.surgeryDateTime;
    final end = c.scheduledEndTime ?? (start != null ? start.add(Duration(minutes: c.estimatedDurationMinutes)) : null);
    final timeStr = start != null && end != null
        ? '${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}'
        : (start != null ? DateFormat('hh:mm a').format(start) : 'Scheduled');

    final isEmergency = (c.priority ?? '').toLowerCase() == 'emergency';

    return InkWell(
      onTap: () => _showCaseActionModal(c, hasConflict, conflictMsgs),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasConflict ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasConflict ? AppTheme.dangerColor : AppTheme.borderColor,
            width: hasConflict ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasConflict ? Icons.warning_amber_rounded : Icons.access_time,
                  size: 11,
                  color: hasConflict ? AppTheme.dangerColor : AppTheme.primaryColor,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasConflict ? AppTheme.dangerColor : AppTheme.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('EMERGENCY', style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                c.otRoom ?? 'OT Slot',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c.patientName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimaryColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              c.surgeryType ?? c.diagnosis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    c.leadSurgeon ?? c.surgeon ?? 'Surgeon TBD',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
                    maxLines: 1,
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

  // ─────────────────────────────────────────────────────────────────────────────
  // MONTHLY VIEW
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMonthlyView() {
    final monthCells = _getDaysOfMonth(_selectedDate);
    const weekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    final List<List<DateTime?>> weeks = [];
    for (int i = 0; i < monthCells.length; i += 7) {
      weeks.add(monthCells.sublist(i, i + 7));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        const minRowHeight = 85.0;
        final availableHeight = constraints.maxHeight - 55.0;
        final calculatedRowHeight = weeks.isNotEmpty ? (availableHeight / weeks.length) : minRowHeight;
        final needsScroll = calculatedRowHeight < minRowHeight;
        final rowHeight = needsScroll ? minRowHeight : calculatedRowHeight;

        final weeksWidget = needsScroll
            ? Column(
                children: weeks.map((week) {
                  return SizedBox(
                    height: rowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: week.map((cell) => Expanded(child: _buildMonthDayCell(cell))).toList(),
                    ),
                  );
                }).toList(),
              )
            : Column(
                children: weeks.map((week) {
                  return Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: week.map((cell) => Expanded(child: _buildMonthDayCell(cell))).toList(),
                    ),
                  );
                }).toList(),
              );

        final gridWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Week days header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: weekDays.map((wd) => Expanded(
                  child: Center(
                    child: Text(
                      wd,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 6),

            // Month weeks
            if (needsScroll)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: weeksWidget,
                ),
              )
            else
              Expanded(child: weeksWidget),
          ],
        );

        if (isDesktop) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: gridWidget),
                const SizedBox(width: 12),
                SizedBox(width: 400, child: _buildMonthSelectedDateDetails()),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: weekDays.map((wd) => Expanded(
                      child: Center(
                        child: Text(
                          wd,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                Column(
                  children: weeks.map((week) {
                    return SizedBox(
                      height: 85,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: week.map((cell) => Expanded(child: _buildMonthDayCell(cell))).toList(),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 420,
                  child: _buildMonthSelectedDateDetails(),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildMonthDayCell(DateTime? cellDate) {
    if (cellDate == null) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC).withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
        ),
      );
    }

    final isSelected = _isSameDay(cellDate, _selectedDate);
    final isToday = _isSameDay(cellDate, DateTime.now());
    final dayCases = _getCasesForDay(cellDate);
    final hasEmergency = dayCases.any((c) => (c.priority ?? '').toLowerCase() == 'emergency');

    return InkWell(
      onTap: () => setState(() => _selectedDate = cellDate),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : (isToday ? const Color(0xFFF0FDF4) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isToday ? AppTheme.secondaryColor : AppTheme.borderColor),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: ClipRect(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
              // Day number & count chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isToday ? AppTheme.secondaryColor : Colors.transparent),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cellDate.day}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected || isToday ? Colors.white : AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                  if (dayCases.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: hasEmergency ? AppTheme.dangerColor.withOpacity(0.15) : AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${dayCases.length}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: hasEmergency ? AppTheme.dangerColor : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),

              // Mini Cases preview
              if (dayCases.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...dayCases.take(2).map((c) {
                      final isEmerg = (c.priority ?? '').toLowerCase() == 'emergency';
                      return Container(
                        margin: const EdgeInsets.only(top: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: isEmerg ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: isEmerg ? AppTheme.dangerColor.withOpacity(0.4) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          '${c.otRoom ?? "OT"}: ${c.patientName.split(" ").first}',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: isEmerg ? AppTheme.dangerColor : const Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    if (dayCases.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 1, left: 2),
                        child: Text(
                          '+${dayCases.length - 2} more',
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMonthSelectedDateDetails() {
    final selectedDayCases = _getCasesForDay(_selectedDate);
    final dayConflicts = _detectDayConflicts(selectedDayCases);
    final dateTitle = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: selectedDayCases.isEmpty ? Colors.grey.shade200 : AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selectedDayCases.length} ${selectedDayCases.length == 1 ? "Surgery" : "Surgeries"} Scheduled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selectedDayCases.isEmpty ? Colors.grey.shade700 : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _viewMode = OtCalendarViewMode.daily);
                      },
                      icon: const Icon(Icons.view_day_outlined, size: 13),
                      label: const Text('View Hour Timeline', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Panel Body: Surgeries list
          Expanded(
            child: selectedDayCases.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 44, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text(
                            'No surgeries scheduled for this date.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select another date in the calendar or schedule a new procedure.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.onScheduleNew != null) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: widget.onScheduleNew,
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Book Surgery', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: selectedDayCases.length,
                    itemBuilder: (context, index) {
                      final c = selectedDayCases[index];
                      final hasConflict = c.dbId != null && dayConflicts.containsKey(c.dbId);
                      final conflictMsgs = c.dbId != null ? (dayConflicts[c.dbId!] ?? []) : <String>[];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: _buildMonthCaseDetailCard(c, hasConflict, conflictMsgs),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCaseDetailCard(OtCase c, bool hasConflict, List<String> conflictMsgs) {
    final start = c.scheduledStartTime ?? c.surgeryDateTime;
    final end = c.scheduledEndTime ?? (start != null ? start.add(Duration(minutes: c.estimatedDurationMinutes)) : null);
    final timeStr = start != null && end != null
        ? '${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}'
        : (start != null ? DateFormat('hh:mm a').format(start) : 'Scheduled');

    final isEmergency = (c.priority ?? '').toLowerCase() == 'emergency';

    return InkWell(
      onTap: () => _showCaseActionModal(c, hasConflict, conflictMsgs),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasConflict ? const Color(0xFFFFF1F2) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasConflict ? AppTheme.dangerColor : AppTheme.borderColor,
            width: hasConflict ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Room badge, time, priority
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c.otRoom ?? 'OT Slot',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  hasConflict ? Icons.warning_amber_rounded : Icons.access_time,
                  size: 12,
                  color: hasConflict ? AppTheme.dangerColor : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasConflict ? AppTheme.dangerColor : const Color(0xFF334155),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('EMERGENCY', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Patient Name & ID
            Text(
              '${c.patientName} (${c.patientId})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryColor),
            ),
            const SizedBox(height: 2),

            // Row 3: Procedure / Diagnosis
            Text(
              c.surgeryType ?? c.diagnosis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Row 4: Surgeon, Anaesthetist, PAC chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Surgeon: ${c.leadSurgeon ?? c.surgeon ?? "TBD"}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.anaesthetist != null && c.anaesthetist!.isNotEmpty)
                        Text(
                          'Anaesthetist: ${c.anaesthetist}',
                          style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildPacChip(c.pacStatus),
              ],
            ),

            // Conflict Warning (if collision detected)
            if (hasConflict && conflictMsgs.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 12, color: AppTheme.dangerColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        conflictMsgs.first,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.dangerColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
    showDialog(
      context: context,
      builder: (ctx) {
        final pacButton = OutlinedButton.icon(
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
        );
        final whoButton = OutlinedButton.icon(
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
        );
        final openButton = ElevatedButton.icon(
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
        );

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: widget.isMobile ? 16 : 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 580,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
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
                        child: Text(
                          c.patientName.isNotEmpty ? c.patientName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              '${c.id} • ${c.otRoom ?? "Theatre TBD"} • ${c.surgeryType ?? c.diagnosis}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
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
                  if (widget.isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        pacButton,
                        const SizedBox(height: 8),
                        whoButton,
                        const SizedBox(height: 8),
                        openButton,
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: pacButton),
                        const SizedBox(width: 10),
                        Expanded(child: whoButton),
                        const SizedBox(width: 10),
                        Expanded(child: openButton),
                      ],
                    ),
                ],
              ),
            ),
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
