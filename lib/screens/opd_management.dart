import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/admin_controller.dart';
import '../controllers/patient_controller.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../utils/date_formatter.dart';

class OPDManagementScreen extends StatefulWidget {
  final bool isMobile;
  const OPDManagementScreen({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<OPDManagementScreen> createState() => _OPDManagementScreenState();
}

class _OPDManagementScreenState extends State<OPDManagementScreen> {
  final AppointmentController _appointmentController = AppointmentController();
  final AdminController _adminController = AdminController();
  final PatientController _patientController = PatientController();

  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  final DateTime _selectedDate = DateTime.now(); // Locked to today for OPD
  String _selectedStatus = 'All';
  String _selectedDoctor = 'All';
  String _searchQuery = '';
  bool _isFilterVisible = false;
  
  List<UserModel> _doctors = [];
  
  // OPD specific flow statuses - Merged Confirmed/Checked-in into Waiting
  final List<String> _statuses = ['All', 'Waiting', 'In Consultation', 'Completed', 'Cancelled', 'No-Show'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDoctors();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Fetch for today only as per OPD requirements
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await _appointmentController.fetchAdminAppointments(
        date: dateStr,
        status: null, // Fetch all to handle merged statuses locally
        doctor: _selectedDoctor == 'All' ? null : _selectedDoctor,
      );
      if (mounted) {
        setState(() {
          _appointments = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final staff = await _adminController.fetchStaff(role: 'Doctor');
      if (mounted) {
        staff.sort((a, b) => a.fullname.compareTo(b.fullname));
        setState(() {
          _doctors = staff;
        });
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    List<AppointmentModel> apps = List.from(_appointments);
    
    // 1. Filter by Status (Merged Confirmed/Checked-in -> Waiting)
    if (_selectedStatus != 'All') {
      if (_selectedStatus == 'Waiting') {
        apps = apps.where((a) => a.status == 'Confirmed' || a.status == 'Checked-in' || a.status == 'Waiting').toList();
      } else {
        apps = apps.where((a) => a.status == _selectedStatus).toList();
      }
    }

    // 2. Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      apps = apps.where((a) {
        return a.patientName.toLowerCase().contains(query) ||
               (a.patientDisplayId?.toLowerCase().contains(query) ?? false) ||
               (a.patientPhone?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // 3. Sort by Time (Today's live list should be chronological)
    apps.sort((a, b) {
      try {
        final timeA = DateFormat('hh:mm a').parse(a.appointmentTime);
        final timeB = DateFormat('hh:mm a').parse(b.appointmentTime);
        return timeA.compareTo(timeB);
      } catch (e) {
        return 0;
      }
    });

    return apps;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
      case 'Waiting': 
      case 'Checked-in': return const Color(0xFF0D9488); // Teal for all waiting states
      case 'In Consultation': return const Color(0xFFF59E0B); // Amber
      case 'Completed': return const Color(0xFF22C55E); // Green
      case 'Cancelled': return const Color(0xFFEF4444); // Red
      case 'No-Show': return const Color(0xFFF97316); // Orange
      case 'Rescheduled': return const Color(0xFF8B5CF6); // Purple
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildSearchAndFilterRow(),
          if (_isFilterVisible) _buildFilterPanel(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(widget.isMobile ? 16 : 24, 24, widget.isMobile ? 16 : 24, 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('OPD Management', style: TextStyle(fontSize: widget.isMobile ? 22 : 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
              const SizedBox(height: 4),
              Text('Today\'s Live Visits: ${DateFormat('dd MMM yyyy').format(_selectedDate)}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showWalkInDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(widget.isMobile ? 'Walk-in' : 'New Walk-in', style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    final isMobile = widget.isMobile;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilterToggle(isMobile),
            ],
          )
        : Row(children: [
            Expanded(flex: 4, child: _buildSearchBar()),
            const SizedBox(width: 16),
            _buildFilterToggle(isMobile),
          ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        const Icon(Icons.search, size: 20, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: const InputDecoration(
              hintText: 'Search patient name, ID, or phone...',
              hintStyle: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterToggle(bool isMobile) {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _isFilterVisible = !_isFilterVisible),
      icon: Icon(_isFilterVisible ? Icons.filter_list_off : Icons.filter_list, size: 18),
      label: const Text('Filter', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        minimumSize: Size(isMobile ? double.infinity : 120, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        elevation: 0,
        side: const BorderSide(color: AppTheme.borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFilterPanel() {
    final isMobile = widget.isMobile;
    return Container(
      margin: EdgeInsets.only(left: isMobile ? 16 : 24, right: isMobile ? 16 : 24, top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        isMobile
          ? Column(children: [
              _buildFilterDropdown('Visit Date', DateFormat('dd-MM-yyyy').format(_selectedDate), [], (v) {}, isMobile: true, isReadOnly: true),
              const SizedBox(height: 14),
              _buildFilterDropdown('Visit Status', _selectedStatus, _statuses, (v) {
                if (v != null) setState(() => _selectedStatus = v);
                _loadData();
              }, isMobile: true),
              const SizedBox(height: 14),
              _buildFilterDropdown('Doctor', _selectedDoctor, ['All', ..._doctors.map((d) => d.fullname)], (v) {
                if (v != null) setState(() => _selectedDoctor = v);
                _loadData();
              }, isMobile: true),
            ])
          : Row(children: [
              Expanded(
                child: _buildFilterDropdown('Visit Date', DateFormat('dd-MM-yyyy').format(_selectedDate), [], (v) {}, isMobile: false, isReadOnly: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterDropdown('Visit Status', _selectedStatus, _statuses, (v) {
                  if (v != null) setState(() => _selectedStatus = v);
                  _loadData();
                }, isMobile: false),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterDropdown('Doctor', _selectedDoctor, ['All', ..._doctors.map((d) => d.fullname)], (v) {
                  if (v != null) setState(() => _selectedDoctor = v);
                  _loadData();
                }, isMobile: false),
              ),
            ]),
        if (_selectedStatus != 'All' || _selectedDoctor != 'All') ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedStatus = 'All';
                  _selectedDoctor = 'All';
                });
                _loadData();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Filters'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ),
        ]
      ]),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged, {required bool isMobile, bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor)),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isReadOnly ? Colors.grey.shade50 : Colors.white,
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isReadOnly 
            ? Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 8),
                Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor)),
                const Spacer(),
                const Icon(Icons.lock_outline, size: 14, color: AppTheme.textSecondaryColor),
              ])
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: value,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 14),
                  items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: onChanged,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final apps = _filteredAppointments;
    if (apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: AppTheme.textSecondaryColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No OPD visits found for today', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 16)),
          ],
        ),
      );
    }

    if (widget.isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: apps.length,
        itemBuilder: (context, index) => _buildMobileCard(apps[index]),
      );
    }

    return _buildDesktopTable(apps);
  }

  Widget _buildDesktopTable(List<AppointmentModel> apps) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - (widget.isMobile ? 32 : 310)),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.backgroundColor),
                  columns: const [
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Patient')),
                    DataColumn(label: Text('Doctor')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: apps.map((app) => DataRow(
                    cells: [
                      DataCell(Text(app.appointmentTime, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(app.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (app.patientDisplayId != null)
                            Text(app.patientDisplayId!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontFamily: 'monospace')),
                        ],
                      )),
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(app.doctorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (app.doctorDisplayId != null && app.doctorDisplayId!.isNotEmpty)
                            Text('ID: ${app.doctorDisplayId}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                        ],
                      )),
                      DataCell(_buildStatusBadge(app.status)),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 20, color: AppTheme.primaryColor),
                            onPressed: () => _showVisitDetails(app),
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_note, size: 22, color: Colors.orange),
                            onPressed: () => _showOverrideDialog(app),
                            tooltip: 'Override Status',
                          ),
                        ],
                      )),
                    ],
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCard(AppointmentModel app) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(app.appointmentTime, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                _buildStatusBadge(app.status),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(app.patientName[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        app.doctorDisplayId != null && app.doctorDisplayId!.isNotEmpty
                            ? 'Doctor: ${app.doctorName} (${app.doctorDisplayId})'
                            : 'Doctor: ${app.doctorName}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showVisitDetails(app),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showOverrideDialog(app),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Override'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade50,
                    foregroundColor: Colors.orange.shade900,
                    elevation: 0,
                    minimumSize: const Size(80, 36),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final label = (status == 'Checked-in' || status == 'Confirmed') ? 'Waiting' : status;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred', style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  void _showVisitDetails(AppointmentModel app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Visit Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailItem('Patient', app.patientName),
                _detailItem('ID', app.patientDisplayId ?? 'N/A'),
                _detailItem('Phone', app.patientPhone ?? 'N/A'),
                _detailItem('Doctor', app.doctorName),
                _detailItem('Time', app.appointmentTime),
                _detailItem('Status', app.status == 'Checked-in' ? 'Waiting' : app.status),
                const Divider(height: 32),
                const Text('Status Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (app.changesLog != null)
                  _buildTimeline(app.changesLog)
                else
                  const Text('No status changes recorded yet.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildTimeline(dynamic log) {
    if (log is! Map) return const SizedBox.shrink();
    final sortedKeys = log.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return Column(
      children: sortedKeys.map((key) {
        final change = log[key];
        DateTime? dt;
        try { dt = DateTime.parse(key); } catch(_) {}
        String text = 'Updated';
        if (change is Map && change.containsKey('status')) {
           final from = change['status']['from'] == 'Checked-in' ? 'Waiting' : change['status']['from'];
           final to = change['status']['to'] == 'Checked-in' ? 'Waiting' : change['status']['to'];
           text = 'Status: $from → $to';
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppTheme.primaryColor),
                  Container(width: 2, height: 20, color: AppTheme.borderColor),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dt != null)
                      Text(DateFormat('dd MMM, hh:mm a').format(dt.toLocal()), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                    Text(text, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showOverrideDialog(AppointmentModel app) {
    final reasonController = TextEditingController();
    String newStatus = app.status == 'Checked-in' ? 'Waiting' : app.status;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Admin Status Override', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _statuses.contains(newStatus) ? newStatus : _statuses[0],
                decoration: const InputDecoration(labelText: 'New Status'),
                items: _statuses.where((s) => s != 'All').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) { if (val != null) setDialogState(() => newStatus = val); },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Override Reason (Mandatory)',
                  hintText: 'Explain why you are changing the status...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason')));
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  await _appointmentController.adminOverrideAppointment(
                    id: app.id!,
                    status: newStatus == 'Waiting' ? 'Checked-in' : newStatus,
                    overrideReason: reasonController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  _loadData();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated successfully'), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                } finally {
                  if (mounted) setDialogState(() => isSaving = false);
                }
              },
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalkInDialog() {
    PatientModel? selectedPatient;
    UserModel? selectedDoctor;
    String time = DateFormat('hh:mm a').format(DateTime.now());
    bool isSaving = false;
    bool isLoadingPatients = false;
    List<PatientModel> allPatients = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (allPatients.isEmpty && !isLoadingPatients) {
            setDialogState(() => isLoadingPatients = true);
            _patientController.fetchPatients().then((p) {
              if (mounted) {
                setDialogState(() {
                  allPatients = p;
                  isLoadingPatients = false;
                });
              }
            }).catchError((e) {
              if (mounted) setDialogState(() => isLoadingPatients = false);
            });
          }

          return AlertDialog(
            title: const Text('Quick Walk-in Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoadingPatients)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ))
                    else
                      DropdownButtonFormField<PatientModel>(
                        value: selectedPatient,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Patient', prefixIcon: Icon(Icons.person_outline)),
                        items: allPatients.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.patientId ?? "N/A"})', overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setDialogState(() => selectedPatient = val),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UserModel>(
                      value: selectedDoctor,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Assign Doctor', prefixIcon: Icon(Icons.medical_services_outlined)),
                      items: _doctors.map((d) => DropdownMenuItem(value: d, child: Text(d.fullname, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setDialogState(() => selectedDoctor = val),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (pickedTime != null) {
                          final now = DateTime.now();
                          final dt = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
                          setDialogState(() => time = DateFormat('hh:mm a').format(dt));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 20, color: AppTheme.primaryColor),
                            const SizedBox(width: 12),
                            Text(time, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (selectedPatient == null || selectedDoctor == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select patient and doctor')));
                    return;
                  }
                  setDialogState(() => isSaving = true);
                  try {
                    final newApp = AppointmentModel(
                      patientId: selectedPatient!.id!,
                      patientName: selectedPatient!.name,
                      department: selectedDoctor!.specialization ?? 'General',
                      doctorName: selectedDoctor!.fullname,
                      appointmentDate: DateFormatter.toUi(DateTime.now()),
                      appointmentTime: time,
                      status: 'Checked-in', // Default to Waiting/Checked-in for walk-ins
                      appointmentType: 'Walk-in',
                    );
                    await _appointmentController.bookAppointment(newApp);
                    Navigator.pop(ctx);
                    _loadData();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Walk-in registered successfully'), backgroundColor: Colors.green));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setDialogState(() => isSaving = false);
                  }
                },
                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Register'),
              ),
            ],
          );
        },
      ),
    );
  }
}
