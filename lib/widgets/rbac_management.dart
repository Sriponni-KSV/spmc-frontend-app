import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../providers/auth_provider.dart';

class RbacManagementWidget extends StatefulWidget {
  final bool isMobile;
  const RbacManagementWidget({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<RbacManagementWidget> createState() => _RbacManagementWidgetState();
}

class _RbacManagementWidgetState extends State<RbacManagementWidget> {
  final AdminController _adminController = AdminController();
  Future<Map<String, dynamic>>? _rbacFuture;

  @override
  void initState() {
    super.initState();
    _loadRbacData();
  }

  void _loadRbacData() {
    setState(() {
      _rbacFuture = _adminController.fetchRbacData();
    });
  }

  void _showAddRoleDialog(BuildContext context, List<dynamic> permissions) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    List<int> selectedPermissions = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Create New Role', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 500 ? 500 : MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Role Name', prefixIcon: Icon(Icons.badge_outlined)),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a role name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                      ),
                      const SizedBox(height: 24),
                      const Text('Select Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: permissions.map((p) {
                          final isSelected = selectedPermissions.contains(p['id']);
                          return FilterChip(
                            label: Text(p['display_name'] ?? p['permission_name']),
                            selected: isSelected,
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
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => isSaving = true);
                  try {
                    await _adminController.createRoleRbac(
                      nameCtrl.text.trim(),
                      descCtrl.text.trim(),
                      selectedPermissions,
                    );
                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadRbacData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Role created successfully!'), backgroundColor: Colors.green.shade600),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                      );
                    }
                  } finally {
                    if (mounted) setDialogState(() => isSaving = false);
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, Map<String, dynamic> role, List<dynamic> permissions, List<dynamic> rolePermissions) {
    bool isSaving = false;
    List<int> selectedPermissions = rolePermissions
        .where((rp) => int.parse(rp['role_id'].toString()) == int.parse(role['id'].toString()))
        .map<int>((rp) => int.parse(rp['permission_id'].toString()))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text("Edit ${role['role_name']} Permissions", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 500 ? 500 : MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Select Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: permissions.map((p) {
                        final isSelected = selectedPermissions.contains(p['id']);
                        return FilterChip(
                          label: Text(p['display_name'] ?? p['permission_name']),
                          selected: isSelected,
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
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  setDialogState(() => isSaving = true);
                  try {
                    await _adminController.updateRolePermissions(
                      role['id'],
                      selectedPermissions,
                    );
                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadRbacData();
                      // Refresh current user's permissions in case their own role was updated
                      Provider.of<AuthProvider>(context, listen: false).refreshPermissions();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Permissions updated successfully!'), backgroundColor: Colors.green.shade600),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                      );
                    }
                  } finally {
                    if (mounted) setDialogState(() => isSaving = false);
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteRoleDialog(BuildContext context, Map<String, dynamic> role) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Delete Role', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete ${role['role_name']}?"),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDeleting ? null : () async {
                setDialogState(() => isDeleting = true);
                try {
                  await _adminController.deleteRole(role['id']);
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadRbacData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Role deleted successfully!'), backgroundColor: Colors.green.shade600),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isDeleting = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: isDeleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context, listen: false).user?.role;
    final bool isSuperAdmin = userRole == 'Super Admin';

    return FutureBuilder<Map<String, dynamic>>(
      future: _rbacFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error loading RBAC data: ${snapshot.error}"));
        }

        final data = snapshot.data ?? {};
        final rawRoles = (data['roles'] as List<dynamic>?) ?? [];
        final roles = List.from(rawRoles);
        final orderedRoles = ['Super Admin', 'Admin', 'Doctor', 'Nurse'];
        roles.sort((a, b) {
          int indexA = orderedRoles.indexOf(a['role_name']);
          int indexB = orderedRoles.indexOf(b['role_name']);
          if (indexA == -1 && indexB == -1) return a['role_name'].compareTo(b['role_name']);
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });
        final permissions = (data['permissions'] as List<dynamic>?) ?? [];
        final rolePermissions = (data['rolePermissions'] as List<dynamic>?) ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(widget.isMobile ? 16 : 24, widget.isMobile ? 16 : 24, widget.isMobile ? 16 : 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Access Control (RBAC)', style: TextStyle(fontSize: widget.isMobile ? 22 : 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Manage roles and assign specific permissions', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddRoleDialog(context, permissions),
                      icon: const Icon(Icons.add_moderator, size: 18),
                      label: Text(widget.isMobile ? 'Add' : 'Create Role', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 12 : 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
                ),
                child: ListView.separated(
                  itemCount: roles.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.borderColor),
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    final rolePermIds = rolePermissions
                        .where((rp) => rp['role_id'] == role['id'])
                        .map((rp) => rp['permission_id'])
                        .toList();
                    final rolePerms = permissions.where((p) => rolePermIds.contains(p['id'])).toList();

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(role['role_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                              if (isSuperAdmin && role['role_name'] != 'Super Admin')
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20),
                                      onPressed: () => _showEditRoleDialog(context, role, permissions, rolePermissions),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _showDeleteRoleDialog(context, role),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (role['description'] != null && role['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(role['description'], style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: rolePerms.isEmpty 
                                ? [const Text('No permissions assigned', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))]
                                : rolePerms.map((p) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                    ),
                                    child: Text(p['display_name'] ?? p['permission_name'], style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                                  )).toList(),
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
      },
    );
  }
}
