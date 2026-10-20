import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';

/// Supported IPD Bed Statuses
enum BedStatus {
  available,
  occupied,
  reserved,
  cleaning,
  maintenance;

  String get label {
    switch (this) {
      case BedStatus.available:
        return 'Available';
      case BedStatus.occupied:
        return 'Occupied';
      case BedStatus.reserved:
        return 'Reserved';
      case BedStatus.cleaning:
        return 'Cleaning';
      case BedStatus.maintenance:
        return 'Maintenance';
    }
  }

  static BedStatus fromString(String? str) {
    switch (str?.toLowerCase().trim()) {
      case 'occupied':
        return BedStatus.occupied;
      case 'reserved':
        return BedStatus.reserved;
      case 'cleaning':
        return BedStatus.cleaning;
      case 'maintenance':
        return BedStatus.maintenance;
      case 'available':
      default:
        return BedStatus.available;
    }
  }

  Color get primaryColor {
    switch (this) {
      case BedStatus.available:
        return const Color(0xFF10B981); // Emerald Green
      case BedStatus.occupied:
        return const Color(0xFFEF4444); // Crimson Rose
      case BedStatus.reserved:
        return const Color(0xFFF59E0B); // Amber Yellow
      case BedStatus.cleaning:
        return const Color(0xFF06B6D4); // Cyan Blue
      case BedStatus.maintenance:
        return const Color(0xFF8B5CF6); // Purple Slate
    }
  }

  Color get backgroundColor {
    switch (this) {
      case BedStatus.available:
        return const Color(0xFFECFDF5);
      case BedStatus.occupied:
        return const Color(0xFFFEF2F2);
      case BedStatus.reserved:
        return const Color(0xFFFFFBEB);
      case BedStatus.cleaning:
        return const Color(0xFFECFEFF);
      case BedStatus.maintenance:
        return const Color(0xFFF5F3FF);
    }
  }

  Color get borderColor {
    switch (this) {
      case BedStatus.available:
        return const Color(0xFFA7F3D0);
      case BedStatus.occupied:
        return const Color(0xFFFECACA);
      case BedStatus.reserved:
        return const Color(0xFFFDE68A);
      case BedStatus.cleaning:
        return const Color(0xFFA5F3FC);
      case BedStatus.maintenance:
        return const Color(0xFFDDD6FE);
    }
  }

  IconData get icon {
    switch (this) {
      case BedStatus.available:
        return Icons.check_circle_outline;
      case BedStatus.occupied:
        return Icons.hotel;
      case BedStatus.reserved:
        return Icons.bookmark_added_outlined;
      case BedStatus.cleaning:
        return Icons.cleaning_services_outlined;
      case BedStatus.maintenance:
        return Icons.build_outlined;
    }
  }
}

/// Interactive graphical ward and bed grid widget
class InteractiveWardBedGrid extends StatefulWidget {
  final List<Map<String, dynamic>> beds;
  final bool isMobile;
  final Function(Map<String, dynamic> bed, String newStatus)? onStatusChanged;
  final Function(Map<String, dynamic> bed)? onOpenPatientDetail;
  final VoidCallback? onRefresh;

  const InteractiveWardBedGrid({
    super.key,
    required this.beds,
    this.isMobile = false,
    this.onStatusChanged,
    this.onOpenPatientDetail,
    this.onRefresh,
  });

  @override
  State<InteractiveWardBedGrid> createState() => _InteractiveWardBedGridState();
}

class _InteractiveWardBedGridState extends State<InteractiveWardBedGrid> {
  String _selectedWardFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _wardList {
    final Set<String> wards = {'All', 'General', 'Semi-Private', 'Private', 'ICU'};
    for (final b in widget.beds) {
      final w = (b['ward_type'] ?? '').toString().trim();
      if (w.isNotEmpty) wards.add(w);
    }
    return wards.toList();
  }

  List<Map<String, dynamic>> get _filteredBeds {
    return widget.beds.where((bed) {
      final bedNum = (bed['bed_number'] ?? '').toString().toLowerCase();
      final ward = (bed['ward_type'] ?? '').toString().toLowerCase();
      final patient = (bed['patient_name'] ?? '').toString().toLowerCase();
      final status = (bed['status'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase().trim();

      final matchesQuery = q.isEmpty ||
          bedNum.contains(q) ||
          ward.contains(q) ||
          patient.contains(q);

      final matchesWard = _selectedWardFilter == 'All' ||
          ward == _selectedWardFilter.toLowerCase();

      final matchesStatus = _selectedStatusFilter == 'All' ||
          status == _selectedStatusFilter.toLowerCase();

      return matchesQuery && matchesWard && matchesStatus;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedBeds {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final bed in _filteredBeds) {
      final ward = (bed['ward_type'] ?? 'General').toString();
      map.putIfAbsent(ward, () => []).add(bed);
    }
    return map;
  }

  int _countByStatus(String statusStr) {
    return widget.beds.where((b) {
      final s = (b['status'] ?? '').toString().toLowerCase();
      return s == statusStr.toLowerCase();
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final totalBeds = widget.beds.length;
    final occupiedCount = _countByStatus('Occupied');
    final availableCount = _countByStatus('Available');
    final reservedCount = _countByStatus('Reserved');
    final cleaningCount = _countByStatus('Cleaning');
    final maintenanceCount = _countByStatus('Maintenance');
    final occupancyRate = totalBeds > 0 ? (occupiedCount / totalBeds * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Status KPI Summary Cards ──────────────────────────────────────
        _buildKpiMetrics(
          total: totalBeds,
          occupied: occupiedCount,
          available: availableCount,
          reserved: reservedCount,
          cleaning: cleaningCount,
          maintenance: maintenanceCount,
          occupancyRate: occupancyRate,
        ),
        const SizedBox(height: 16),

        // ─── Filter & Search Bar ──────────────────────────────────────────
        _buildControlBar(),
        const SizedBox(height: 20),

        // ─── Ward Grid List ───────────────────────────────────────────────
        if (_filteredBeds.isEmpty)
          _buildEmptyState()
        else
          ..._groupedBeds.entries.map((entry) {
            return _buildWardSection(entry.key, entry.value);
          }),
      ],
    );
  }

  // ─── KPI Metrics ─────────────────────────────────────────────────────────

  Widget _buildKpiMetrics({
    required int total,
    required int occupied,
    required int available,
    required int reserved,
    required int cleaning,
    required int maintenance,
    required int occupancyRate,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
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
                child: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('ward_bed_occupancy_matrix', fallback: 'Ward & Bed Occupancy Matrix'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total Total Beds • $occupancyRate% Hospital Bed Occupancy',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              if (widget.onRefresh != null)
                IconButton(
                  tooltip: 'Refresh Matrix',
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: widget.onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Occupancy Progress Meter
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (total > 0 && occupied > 0)
                    Expanded(
                      flex: occupied,
                      child: Container(color: BedStatus.occupied.primaryColor),
                    ),
                  if (total > 0 && reserved > 0)
                    Expanded(
                      flex: reserved,
                      child: Container(color: BedStatus.reserved.primaryColor),
                    ),
                  if (total > 0 && cleaning > 0)
                    Expanded(
                      flex: cleaning,
                      child: Container(color: BedStatus.cleaning.primaryColor),
                    ),
                  if (total > 0 && maintenance > 0)
                    Expanded(
                      flex: maintenance,
                      child: Container(color: BedStatus.maintenance.primaryColor),
                    ),
                  if (total > 0 && available > 0)
                    Expanded(
                      flex: available,
                      child: Container(color: BedStatus.available.primaryColor),
                    ),
                  if (total == 0)
                    Expanded(child: Container(color: Colors.grey.shade300)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Status Chips / Quick Status Filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill('All', 'All Beds ($total)', Colors.grey.shade700, Colors.grey.shade100),
              _buildStatusPill('Available', 'Available ($available)', BedStatus.available.primaryColor, BedStatus.available.backgroundColor),
              _buildStatusPill('Occupied', 'Occupied ($occupied)', BedStatus.occupied.primaryColor, BedStatus.occupied.backgroundColor),
              _buildStatusPill('Reserved', 'Reserved ($reserved)', BedStatus.reserved.primaryColor, BedStatus.reserved.backgroundColor),
              _buildStatusPill('Cleaning', 'Cleaning ($cleaning)', BedStatus.cleaning.primaryColor, BedStatus.cleaning.backgroundColor),
              _buildStatusPill('Maintenance', 'Maintenance ($maintenance)', BedStatus.maintenance.primaryColor, BedStatus.maintenance.backgroundColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String statusKey, String label, Color color, Color bg) {
    final isSelected = _selectedStatusFilter == statusKey;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatusFilter = statusKey;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: isSelected ? 1.0 : 0.4), width: 1.5),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Control Bar (Ward filter + Search) ───────────────────────────────────

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: widget.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWardTabs(),
                const SizedBox(height: 10),
                _buildSearchField(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildWardTabs()),
                const SizedBox(width: 16),
                SizedBox(width: 280, child: _buildSearchField()),
              ],
            ),
    );
  }

  Widget _buildWardTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _wardList.map((ward) {
          final isSelected = _selectedWardFilter == ward;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(ward == 'All' ? 'All Wards' : '$ward Ward'),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor,
              backgroundColor: const Color(0xFFF1F5F9),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedWardFilter = ward);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search bed or patient...',
        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  // ─── Ward Section ────────────────────────────────────────────────────────

  Widget _buildWardSection(String wardName, List<Map<String, dynamic>> wardBeds) {
    final total = wardBeds.length;
    final available = wardBeds.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'available').length;
    final occupied = wardBeds.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'occupied').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                Icon(
                  wardName == 'ICU' ? Icons.monitor_heart : Icons.bedroom_parent_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  '$wardName Ward',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$available / $total Available',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                if (occupied > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BedStatus.occupied.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$occupied Occupied',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: BedStatus.occupied.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bed Grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final int crossAxisCount = width > 1100
                    ? 5
                    : width > 800
                        ? 4
                        : width > 520
                            ? 3
                            : 2;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: wardBeds.length,
                  itemBuilder: (context, index) {
                    final bed = wardBeds[index];
                    return _buildBedCard(bed);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Individual Bed Card ─────────────────────────────────────────────────

  Widget _buildBedCard(Map<String, dynamic> bed) {
    final status = BedStatus.fromString(bed['status']?.toString());
    final bedNumber = (bed['bed_number'] ?? '--').toString();
    final patientName = (bed['patient_name'] ?? '').toString();
    final patientAge = bed['patient_age'];
    final patientGender = (bed['patient_gender'] ?? '').toString();
    final doctorName = (bed['doctor_name'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBedDetailModal(bed),
        borderRadius: BorderRadius.circular(14),
        hoverColor: status.primaryColor.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: status.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: status.borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: status.primaryColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar: Bed Number + Status Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: status.borderColor),
                    ),
                    child: Text(
                      bedNumber,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: status.primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: status.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(status.icon, size: 14, color: status.primaryColor),
                  ),
                ],
              ),

              // Center Content: Patient info or Status Illustration
              if (status == BedStatus.occupied && patientName.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${patientAge != null ? '$patientAge y • ' : ''}$patientGender',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      status == BedStatus.available
                          ? Icons.king_bed_outlined
                          : status == BedStatus.cleaning
                              ? Icons.sanitizer_outlined
                              : status == BedStatus.maintenance
                                  ? Icons.handyman_outlined
                                  : Icons.bookmark_border_rounded,
                      size: 20,
                      color: status.primaryColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Bottom Footnote
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    status == BedStatus.occupied
                        ? (doctorName.isNotEmpty ? 'Dr. $doctorName' : 'Admitted')
                        : status == BedStatus.available
                            ? 'Ready for intake'
                            : status == BedStatus.reserved
                                ? 'Reserved'
                                : status == BedStatus.cleaning
                                    ? 'Sanitizing'
                                    : 'Under repair',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: status.primaryColor.withValues(alpha: 0.9),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: status.primaryColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bed Detail Modal ────────────────────────────────────────────────────

  void _showBedDetailModal(Map<String, dynamic> bed) {
    final status = BedStatus.fromString(bed['status']?.toString());
    final bedNumber = (bed['bed_number'] ?? '--').toString();
    final wardType = (bed['ward_type'] ?? 'General').toString();
    final patientName = (bed['patient_name'] ?? '').toString();
    final patientDisplayId = (bed['patient_display_id'] ?? '').toString();
    final doctorName = (bed['doctor_name'] ?? '').toString();
    final admissionDate = bed['admission_date'];
    final phone = (bed['patient_phone'] ?? '').toString();
    final age = bed['patient_age'];
    final gender = (bed['patient_gender'] ?? '').toString();
    final reason = (bed['reason_for_admission'] ?? '').toString();

    String formattedDate = '--';
    if (admissionDate != null) {
      try {
        final parsed = DateTime.parse(admissionDate.toString()).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (modalCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: status.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(status.icon, color: status.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bed $bedNumber ($wardType Ward)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: status.primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.label.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: status.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // If Occupied: Patient Info Card
                  if (status == BedStatus.occupied && patientName.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patientName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                    ),
                                    Text(
                                      'ID: $patientDisplayId • ${age != null ? '$age y • ' : ''}$gender',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          _buildDetailRow('Admitted By / Doctor', doctorName.isNotEmpty ? 'Dr. $doctorName' : '--', Icons.person_outline),
                          const SizedBox(height: 8),
                          _buildDetailRow('Admission Date', formattedDate, Icons.event_available_outlined),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Contact Phone', phone, Icons.phone_outlined),
                          ],
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Admission Reason', reason, Icons.notes_outlined),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action button to open patient chart
                    if (widget.onOpenPatientDetail != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(modalCtx).pop();
                            widget.onOpenPatientDetail!(bed);
                          },
                          icon: const Icon(Icons.medical_information_outlined, size: 18),
                          label: const Text('Open Patient Chart & Clinical Notes'),
                          style: AppTheme.primaryButton,
                        ),
                      ),
                    const SizedBox(height: 20),
                  ] else ...[
                    // Bed Description info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: status.backgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: status.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(status.icon, color: status.primaryColor, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status == BedStatus.available
                                      ? 'Ready for Admission'
                                      : status == BedStatus.reserved
                                          ? 'Bed is currently reserved for a scheduled patient'
                                          : status == BedStatus.cleaning
                                              ? 'Bed is undergoing sanitization & housekeeping'
                                              : 'Bed is currently undergoing maintenance or inspection',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: status.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ward: $wardType • Bed No: $bedNumber',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: status.primaryColor.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Change Bed Status Controls
                  const Text(
                    'Quick Bed Status Change',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status != BedStatus.available)
                        _buildStatusTransitionBtn(modalCtx, bed, BedStatus.available, 'Set Available', Icons.check_circle_outline),
                      if (status != BedStatus.reserved)
                        _buildStatusTransitionBtn(modalCtx, bed, BedStatus.reserved, 'Reserve Bed', Icons.bookmark_border_rounded),
                      if (status != BedStatus.cleaning)
                        _buildStatusTransitionBtn(modalCtx, bed, BedStatus.cleaning, 'Mark Cleaning', Icons.cleaning_services_outlined),
                      if (status != BedStatus.maintenance)
                        _buildStatusTransitionBtn(modalCtx, bed, BedStatus.maintenance, 'Set Maintenance', Icons.build_outlined),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(modalCtx).pop(),
                        style: AppTheme.cancelButton,
                        child: const Text('Close'),
                      ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTransitionBtn(
    BuildContext modalCtx,
    Map<String, dynamic> bed,
    BedStatus newStatus,
    String label,
    IconData icon,
  ) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 15, color: newStatus.primaryColor),
      label: Text(label, style: TextStyle(color: newStatus.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: newStatus.borderColor, width: 1.5),
        backgroundColor: newStatus.backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        Navigator.of(modalCtx).pop();
        if (widget.onStatusChanged != null) {
          widget.onStatusChanged!(bed, newStatus.label);
        }
      },
    );
  }

  Widget _buildEmptyState() {
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
          Icon(Icons.hotel_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No beds found matching your filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search query, ward filter, or status criteria',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}
