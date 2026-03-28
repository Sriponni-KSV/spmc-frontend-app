import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

// --- Models ---

class PatientModel {
  final String name;
  final String age;
  final String phone;
  final String initials;

  PatientModel({
    required this.name,
    required this.age,
    required this.phone,
    required this.initials,
  });
}

// --- Shared Dashboard Widgets ---

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final String subLabel;
  final IconData icon;
  final Color color;
  final bool isMobile;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subLabel,
    required this.icon,
    required this.color,
    required this.isMobile,
  }) : super(key: key);

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? widget.color.withOpacity(0.5)
                : AppTheme.borderColor.withOpacity(0.5),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered ? AppTheme.cardShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                Text(
                  widget.subLabel,
                  style: TextStyle(
                    color: widget.subLabel.startsWith('+')
                        ? AppTheme.successColor
                        : widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.title,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (widget.isMobile) {
      return SizedBox(
        width: (MediaQuery.of(context).size.width - 48) / 2,
        child: card,
      );
    }
    return card;
  }
}

class LiveClock extends StatefulWidget {
  const LiveClock({Key? key}) : super(key: key);

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEE, MMM d, yyyy').format(_currentTime),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('hh:mm:ss a').format(_currentTime),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isHovered
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHovered
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SpeedDialChild {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SpeedDialChild({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class CustomSpeedDial extends StatefulWidget {
  final List<SpeedDialChild> children;

  const CustomSpeedDial({Key? key, required this.children}) : super(key: key);

  @override
  State<CustomSpeedDial> createState() => _CustomSpeedDialState();
}

class _CustomSpeedDialState extends State<CustomSpeedDial>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen)
          ...widget.children.asMap().entries.map((entry) {
            SpeedDialChild child = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeTransition(
                opacity: _expandAnimation,
                child: ScaleTransition(
                  alignment: Alignment.bottomRight,
                  scale: _expandAnimation,
                  child: InkWell(
                    onTap: () {
                      _toggle();
                      child.onTap();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: child.color,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(child.icon, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            child.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _isOpen
                    ? const Color(0xFFE53E3E)
                    : const Color(0xFF005691),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (Widget child, Animation<double> anim) {
                    return RotationTransition(
                      turns: _isOpen
                          ? anim
                          : Tween<double>(begin: 0.125, end: 0).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  child: Icon(
                    _isOpen ? Icons.close : Icons.add,
                    key: ValueKey<bool>(_isOpen),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Nurse-Specific Widgets ---

class SearchOverlay extends StatefulWidget {
  const SearchOverlay({Key? key}) : super(key: key);

  @override
  _SearchOverlayState createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<PatientModel> _samplePatients = [
    PatientModel(
      name: 'John Smith',
      age: '45y',
      phone: '555-0123',
      initials: 'JS',
    ),
    PatientModel(
      name: 'Sarah Johnson',
      age: '32y',
      phone: '555-0124',
      initials: 'SJ',
    ),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 650,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Input Row
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: AppTheme.iconColor,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontFamily: AppTheme.fontFamily,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Search patients, appointments, or actions...',
                            hintStyle: TextStyle(color: AppTheme.iconColor),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.iconColor,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.borderColor),

                // Content Area
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Quick Actions'),
                        const SizedBox(height: 16),
                        _buildQuickAction(
                          icon: Icons.person_add_alt_1_outlined,
                          label: 'New Patient',
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(height: 12),
                        _buildQuickAction(
                          icon: Icons.calendar_month_outlined,
                          label: 'Book Appointment',
                          color: AppTheme.primaryColor,
                        ),

                        const SizedBox(height: 32),
                        _buildSectionTitle('Patients (3)'),
                        const SizedBox(height: 16),
                        ..._samplePatients
                            .map((p) => _buildPatientItem(p))
                            .toList(),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildShortcutHint('/', 'to search'),
                      const SizedBox(width: 24),
                      _buildShortcutHint('Esc', 'to close'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondaryColor,
        fontFamily: AppTheme.fontFamily,
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientItem(PatientModel patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            radius: 20,
            child: Text(
              patient.initials,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  '${patient.age} • ${patient.phone}',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Book',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutHint(String key, String action) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryColor,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          action,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

class PatientInfoCard extends StatelessWidget {
  final String name;
  final String info;
  final String initials;
  final List<String> tags;
  final VoidCallback onView;
  final VoidCallback onBook;

  const PatientInfoCard({
    Key? key,
    required this.name,
    required this.info,
    required this.initials,
    required this.tags,
    required this.onView,
    required this.onBook,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(
                  0xFF005691,
                ), // Dark blue from image
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      info,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => HealthTag(label: tag)).toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (tags.isEmpty) const SizedBox(height: 38), // placeholder spacing
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Color(0xFF2D3748),
                  ),
                  label: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onBook,
                  icon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Book',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005691),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HealthTag extends StatelessWidget {
  final String label;

  const HealthTag({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;

    switch (label.toLowerCase()) {
      case 'diabetic':
        color = const Color(0xFFD53F8C);
        bgColor = const Color(0xFFFFF5F7);
        break;
      case 'high risk':
        color = const Color(0xFFE53E3E);
        bgColor = const Color(0xFFFFF5F5);
        break;
      case 'hypertension':
        color = const Color(0xFFDD6B20);
        bgColor = const Color(0xFFFFFAF0);
        break;
      default:
        color = AppTheme.primaryColor;
        bgColor = AppTheme.primaryColor.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;

    switch (status.toLowerCase()) {
      case 'active':
        color = const Color(0xFF38A169);
        bgColor = const Color(0xFFF0FFF4);
        break;
      case 'inactive':
        color = const Color(0xFF718096);
        bgColor = const Color(0xFFEDF2F7);
        break;
      default:
        color = AppTheme.primaryColor;
        bgColor = AppTheme.primaryColor.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
