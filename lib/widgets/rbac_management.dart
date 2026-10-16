import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../providers/auth_provider.dart';
import 'custom_dropdown_search.dart';

class RbacManagementWidget extends StatefulWidget {
  final bool isMobile;
  const RbacManagementWidget({super.key, required this.isMobile});

  @override
  State<RbacManagementWidget> createState() => _RbacManagementWidgetState();
}

class _RbacManagementWidgetState extends State<RbacManagementWidget> {
  final AdminController _adminController = AdminController();
  Future<Map<String, dynamic>>? _rbacFuture;
  int _activeTab = 0; // 0: Roles & Permissions, 1: User Access Directory
  String _userSearchQuery = '';
  final TextEditingController _userSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRbacData();
  }

  @override
  void dispose() {
    _userSearchCtrl.dispose();
    super.dispose();
  }

  void _loadRbacData() {
    setState(() {
      _rbacFuture = _adminController.fetchRbacData();
    });
  }

  void _showAddRoleDialog(
    BuildContext context,
    List<dynamic> permissions,
    List<dynamic> existingRoles,
  ) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isCustomRole = false;
    List<int> selectedPermissions = [];
    String? selectedRoleName;

    final existingRoleNames = existingRoles
        .map((role) => role['role_name'].toString().toLowerCase())
        .toSet();
    const predefinedRoleNames = [
      'Doctor',
      'Nurse',
      'Front Desk',
      'Receptionist',
      'Anaesthetist',
      'Lab',
      'Pharmacy',
      'Billing Executive',
    ];
    final availableRoleNames = predefinedRoleNames
        .where((role) => !existingRoleNames.contains(role.toLowerCase()))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Create New Role',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 540
                  ? 540
                  : MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Role Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                isCustomRole = !isCustomRole;
                                selectedRoleName = null;
                                nameCtrl.clear();
                              });
                            },
                            child: Text(
                              isCustomRole
                                  ? 'Select from standard roles'
                                  : 'Enter custom role name',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (!isCustomRole && availableRoleNames.isNotEmpty)
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select role',
                          dropdownItems: availableRoleNames,
                          value: selectedRoleName,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedRoleName = value;
                            });
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please select a role'
                              : null,
                        )
                      else
                        TextFormField(
                          controller: nameCtrl,
                          maxLength: 50,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                            hintText: 'e.g. Radiologist, Dietitian',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Role name cannot be empty';
                            }
                            if (existingRoleNames.contains(value.trim().toLowerCase())) {
                              return 'A role with this name already exists';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: descCtrl,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description_outlined),
                          hintText: 'Enter role responsibilities and scope',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Assign Functional Permissions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select the active permissions this role is granted across the system:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: permissions.map((p) {
                          final isSelected = selectedPermissions.contains(p['id']);
                          return FilterChip(
                            label: Text(
                              p['display_name'] ?? p['permission_name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.primaryColor : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                            checkmarkColor: AppTheme.primaryColor,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedPermissions.add(p['id']);
                                } else {
                                  selectedPermissions.remove(p['id']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final finalRoleName = isCustomRole
                            ? nameCtrl.text.trim()
                            : (selectedRoleName ?? nameCtrl.text.trim());
                        if (finalRoleName.isEmpty) return;

                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSaving = true);
                        try {
                          await _adminController.createRoleRbac(
                            finalRoleName,
                            descCtrl.text.trim(),
                            selectedPermissions,
                          );
                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadRbacData();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text("Role '$finalRoleName' created successfully!"),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Role'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditRoleDialog(
    BuildContext context,
    Map<String, dynamic> role,
    List<dynamic> permissions,
    List<dynamic> rolePermissions,
  ) {
    bool isSaving = false;
    List<int> selectedPermissions = rolePermissions
        .where(
          (rp) =>
              int.parse(rp['role_id'].toString()) ==
              int.parse(role['id'].toString()),
        )
        .map<int>((rp) => int.parse(rp['permission_id'].toString()))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(
              "Edit '${role['role_name']}' Permissions",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 520
                  ? 520
                  : MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Functional Access Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toggle the functional permissions granted to users with this role:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: permissions.map((p) {
                        final isSelected = selectedPermissions.contains(p['id']);
                        return FilterChip(
                          label: Text(
                            p['display_name'] ?? p['permission_name'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryColor : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.primaryColor,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedPermissions.add(p['id']);
                              } else {
                                selectedPermissions.remove(p['id']);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: isSaving
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        setDialogState(() => isSaving = true);
                        try {
                          await _adminController.updateRolePermissions(
                            role['id'],
                            selectedPermissions,
                          );
                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadRbacData();
                            auth.refreshPermissions();

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Permissions for '${role['role_name']}' updated successfully!",
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteRoleDialog(
    BuildContext context,
    Map<String, dynamic> role,
    int assignedCount,
  ) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Delete Role',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to delete the role '${role['role_name']}'?",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_person_outlined, size: 20, color: AppTheme.dangerColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assignedCount > 0
                            ? "$assignedCount staff member(s) currently belong to this role. Deleting this role will immediately unassign their role, hide all functionalities, and display 'Access Denied' on their screens."
                            : "Deleting this role will immediately revoke this functionality and prevent any user from accessing it.",
                        style: const TextStyle(fontSize: 12, color: AppTheme.dangerColor, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              style: AppTheme.cancelButton,
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      setDialogState(() => isDeleting = true);
                      try {
                        await _adminController.deleteRole(role['id']);
                        if (mounted && ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadRbacData();
                          auth.refreshPermissions();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text("Role '${role['role_name']}' deleted. Assigned users now see 'Access Denied'."),
                              backgroundColor: Colors.green.shade600,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppTheme.dangerColor,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setDialogState(() => isDeleting = false);
                      }
                    },
              style: AppTheme.dangerButton,
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Delete Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeUserRoleDialog(
    BuildContext context,
    Map<String, dynamic> user,
    List<dynamic> roles,
  ) {
    int? selectedRoleId = user['role_id'] != null ? int.tryParse(user['role_id'].toString()) : null;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(
              "Assign Role for ${user['fullname'] ?? user['email']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 450
                  ? 450
                  : MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Assigned Role',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedRoleId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'No Role Assigned (Access Denied)',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...roles.map((r) => DropdownMenuItem<int?>(
                            value: int.parse(r['id'].toString()),
                            child: Text(r['role_name'].toString()),
                          )),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRoleId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedRoleId == null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppTheme.dangerColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Unassigning role will immediately block user access and show "Access Denied".',
                              style: TextStyle(fontSize: 11, color: AppTheme.dangerColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: isSaving
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        setDialogState(() => isSaving = true);
                        try {
                          await _adminController.updateUserRole(user['id'], selectedRoleId);
                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadRbacData();
                            auth.refreshPermissions();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('User role updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Update Role'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final bool isSuperAdmin =
        currentUser?.role == 'Super Admin' || currentUser?.role == 'Admin';

    return FutureBuilder<Map<String, dynamic>>(
      future: _rbacFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 48),
                  const SizedBox(height: 12),
                  Text("Error loading RBAC data: ${snapshot.error}"),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadRbacData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final rawRoles = (data['roles'] as List<dynamic>?) ?? [];
        final roles = List.from(rawRoles);
        final orderedRoles = [
          'Super Admin',
          'Admin',
          'Doctor',
          'Nurse',
          'Front Desk',
          'Receptionist',
          'Anaesthetist',
          'Lab',
          'Pharmacy',
        ];
        roles.sort((a, b) {
          int indexA = orderedRoles.indexOf(a['role_name']);
          int indexB = orderedRoles.indexOf(b['role_name']);
          if (indexA == -1 && indexB == -1) {
            return a['role_name'].toString().compareTo(b['role_name'].toString());
          }
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });

        final permissions = (data['permissions'] as List<dynamic>?) ?? [];
        final rolePermissions = (data['rolePermissions'] as List<dynamic>?) ?? [];
        final rawUsers = (data['users'] as List<dynamic>?) ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: EdgeInsets.fromLTRB(
                widget.isMobile ? 16 : 24,
                widget.isMobile ? 16 : 24,
                widget.isMobile ? 16 : 24,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Access Control (RBAC)',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 22 : 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manage live roles, view staff functional access, and assign permissions',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showAddRoleDialog(context, permissions, roles),
                      icon: const Icon(Icons.add_moderator, size: 18),
                      label: Text(
                        widget.isMobile ? 'Add' : 'Create Role',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: AppTheme.dangerButton,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Navigation: Roles & Permissions vs User Access Directory
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 16 : 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 0),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 0
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.security_outlined,
                              size: 18,
                              color: _activeTab == 0 ? Colors.white : AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Roles & Permissions (${roles.length})",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _activeTab == 0 ? Colors.white : AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 1),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeTab == 1
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_alt_outlined,
                              size: 18,
                              color: _activeTab == 1 ? Colors.white : AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "User Access Directory (${rawUsers.length})",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _activeTab == 1 ? Colors.white : AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _activeTab == 0
                  ? _buildRolesList(roles, permissions, rolePermissions, rawUsers, isSuperAdmin)
                  : _buildUserAccessDirectory(rawUsers, roles, permissions, rolePermissions, isSuperAdmin),
            ),
          ],
        );
      },
    );
  }

  // ── Tab 0: Roles & Permissions View ──
  Widget _buildRolesList(
    List<dynamic> roles,
    List<dynamic> permissions,
    List<dynamic> rolePermissions,
    List<dynamic> users,
    bool isSuperAdmin,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 16 : 24,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: ListView.separated(
        itemCount: roles.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: AppTheme.borderColor),
        itemBuilder: (context, index) {
          final role = roles[index];
          final rolePermIds = rolePermissions
              .where((rp) => rp['role_id'] == role['id'])
              .map((rp) => rp['permission_id'])
              .toList();
          final rolePerms = permissions
              .where((p) => rolePermIds.contains(p['id']))
              .toList();

          final assignedUsers = users
              .where((u) => u['role_id'] == role['id'])
              .toList();
          final isSystemRole =
              role['role_name'] == 'Super Admin' || role['role_name'] == 'Admin';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          role['role_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isSystemRole)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Protected System Role',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isSuperAdmin && !isSystemRole)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            tooltip: 'Edit Permissions',
                            onPressed: () => _showEditRoleDialog(
                              context,
                              role,
                              permissions,
                              rolePermissions,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.dangerColor,
                              size: 20,
                            ),
                            tooltip: 'Delete Role',
                            onPressed: () => _showDeleteRoleDialog(
                              context,
                              role,
                              assignedUsers.length,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (role['description'] != null &&
                    role['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    role['description'],
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Assigned Staff snippet
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondaryColor),
                    const SizedBox(width: 4),
                    Text(
                      assignedUsers.isEmpty
                          ? 'No staff assigned'
                          : 'Assigned Staff (${assignedUsers.length}): ${assignedUsers.map((u) => u['fullname'] ?? u['email']).take(4).join(', ')}${assignedUsers.length > 4 ? ' +${assignedUsers.length - 4} more' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: assignedUsers.isEmpty ? Colors.grey : AppTheme.primaryColor,
                        fontWeight: assignedUsers.isEmpty ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Functional Access (Live Permissions)
                const Text(
                  'Functional Access:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: rolePerms.isEmpty
                      ? <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'No permissions assigned (Restricted access)',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ]
                      : rolePerms.map<Widget>((p) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 12,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  p['display_name'] ?? p['permission_name'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Tab 1: User Access Directory View ──
  Widget _buildUserAccessDirectory(
    List<dynamic> users,
    List<dynamic> roles,
    List<dynamic> permissions,
    List<dynamic> rolePermissions,
    bool isSuperAdmin,
  ) {
    final query = _userSearchQuery.trim().toLowerCase();
    final filteredUsers = users.where((u) {
      if (query.isEmpty) return true;
      final name = (u['fullname'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || role.contains(query);
    }).toList();

    return Column(
      children: [
        // Search bar
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: widget.isMobile ? 16 : 24,
            vertical: 4,
          ),
          child: TextField(
            controller: _userSearchCtrl,
            onChanged: (val) => setState(() => _userSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search staff by name, email, or role...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _userSearchCtrl.clear();
                        setState(() => _userSearchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: widget.isMobile ? 16 : 24,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
            ),
            child: filteredUsers.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No staff users matching search criteria.',
                        style: TextStyle(color: AppTheme.textSecondaryColor),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredUsers.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppTheme.borderColor),
                    itemBuilder: (context, index) {
                      final u = filteredUsers[index];
                      final roleName = u['role']?.toString();
                      final hasRole = roleName != null && roleName.isNotEmpty;
                      final roleId = u['role_id'];

                      // Calculate effective permissions for this user
                      final userPermIds = hasRole
                          ? rolePermissions
                              .where((rp) => rp['role_id'] == roleId)
                              .map((rp) => rp['permission_id'])
                              .toList()
                          : [];
                      final userPerms = permissions
                          .where((p) => userPermIds.contains(p['id']))
                          .toList();

                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u['fullname'] ?? u['email'] ?? 'Staff User',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        u['email'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    // Role Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: hasRole
                                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                            : AppTheme.dangerColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: hasRole
                                              ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                              : AppTheme.dangerColor.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        hasRole ? roleName : 'No Role (Access Denied)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasRole
                                              ? AppTheme.primaryColor
                                              : AppTheme.dangerColor,
                                        ),
                                      ),
                                    ),
                                    if (isSuperAdmin) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _showChangeUserRoleDialog(
                                          context,
                                          u,
                                          roles,
                                        ),
                                        icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                                        label: const Text('Change Role'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          textStyle: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Effective Live Functional Access
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Access: ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: !hasRole
                                      ? const Row(
                                          children: [
                                            Icon(
                                              Icons.block,
                                              size: 14,
                                              color: AppTheme.dangerColor,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Access Denied — User has no functional role and cannot perform actions',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.dangerColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : userPerms.isEmpty
                                          ? const Text(
                                              'No permissions assigned to this role (Access Denied for restricted operations)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            )
                                          : Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: userPerms.map<Widget>((p) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.backgroundColor,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: AppTheme.borderColor,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    p['display_name'] ?? p['permission_name'],
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.textPrimaryColor,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
