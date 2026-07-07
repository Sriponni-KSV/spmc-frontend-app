import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../controllers/nurse/nurse_controller.dart';
import '../widgets/custom_dropdown_search.dart';
import '../services/media_service.dart';
import 'dart:io' as io;

class NurseProfileView extends StatefulWidget {
  const NurseProfileView({Key? key}) : super(key: key);

  @override
  State<NurseProfileView> createState() => _NurseProfileViewState();
}

class _NurseProfileViewState extends State<NurseProfileView> {
  bool _isEditingProfile = false;
  bool _isLoading = false;
  bool _isUploadingCert = false;
  NurseController get _nurseController => NurseController();

  Future<void> _pickAndUploadCert() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        List<int>? fileBytes = file.bytes;

        // Fallback for mobile devices where file.bytes can be null
        if (fileBytes == null && file.path != null) {
          fileBytes = io.File(file.path!).readAsBytesSync();
        }

        if (fileBytes != null) {
          setState(() => _isUploadingCert = true);
          try {
            final secureUrl = await MediaService.uploadToCloudinary(
              fileBytes: fileBytes,
              fileName: file.name,
              folder: 'nurses',
            );
            if (secureUrl != null) {
              setState(() {
                _regCertController.text = secureUrl;
              });
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Certificate uploaded successfully!', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Certificate upload failed: $e', style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.red,
              ),
            );
          } finally {
            if (mounted) {
              setState(() => _isUploadingCert = false);
            }
          }
        }
      }
    } catch (e) {
      print('Error picking certificate file: $e');
    }
  }

  // Basic Controllers
  TextEditingController? __nameController;
  TextEditingController get _nameController => __nameController ??= TextEditingController();
  
  TextEditingController? __emailController;
  TextEditingController get _emailController => __emailController ??= TextEditingController();

  TextEditingController? __bioController;
  TextEditingController get _bioController => __bioController ??= TextEditingController();

  TextEditingController? __mobileController;
  TextEditingController get _mobileController => __mobileController ??= TextEditingController();

  // Nurse Specific Controllers
  TextEditingController? __qualController;
  TextEditingController get _qualController => __qualController ??= TextEditingController();

  TextEditingController? __nursingLicenseController;
  TextEditingController get _nursingLicenseController => __nursingLicenseController ??= TextEditingController();

  TextEditingController? __yearsExpController;
  TextEditingController get _yearsExpController => __yearsExpController ??= TextEditingController();

  TextEditingController? __regCertController;
  TextEditingController get _regCertController => __regCertController ??= TextEditingController();

  TextEditingController? __shiftTypeController;
  TextEditingController get _shiftTypeController => __shiftTypeController ??= TextEditingController();

  TextEditingController? __slotStartController;
  TextEditingController get _slotStartController => __slotStartController ??= TextEditingController();

  TextEditingController? __slotEndController;
  TextEditingController get _slotEndController => __slotEndController ??= TextEditingController();

  List<String>? _availableDays;
  List<String>? _weeklyOffDays;
  List<String>? _specificLeaveDates;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController.text = user?.rawFullname ?? '';
    _emailController.text = user?.email ?? '';
    _bioController.text = user?.bio ?? '';
    _mobileController.text = user?.mobile ?? '';

    _qualController.text = user?.qualification ?? '';
    _nursingLicenseController.text = user?.nursingRegistrationNumber ?? '';
    _yearsExpController.text = user?.yearsOfExperience ?? '';
    _regCertController.text = user?.registrationCertificate ?? '';
    _shiftTypeController.text = (user?.shiftType != null && user!.shiftType!.isNotEmpty)
          ? user.shiftType!
          : 'Day Shift';
    _slotStartController.text = user?.shiftStartTime ?? '';
    _slotEndController.text = user?.shiftEndTime ?? '';

    _availableDays = user?.workingDays != null ? List.from(user!.workingDays!) : [];
    // Ensure all days not in availableDays are in weeklyOffDays
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    _weeklyOffDays = allDays.where((d) => !_availableDays!.contains(d)).toList();
    
    _specificLeaveDates = user?.specificLeaveDates != null ? List.from(user!.specificLeaveDates!) : [];
  }

  @override
  void dispose() {
    __nameController?.dispose();
    __emailController?.dispose();
    __bioController?.dispose();
    __mobileController?.dispose();
    __qualController?.dispose();
    __nursingLicenseController?.dispose();
    __yearsExpController?.dispose();
    __regCertController?.dispose();
    __shiftTypeController?.dispose();
    __slotStartController?.dispose();
    __slotEndController?.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    // Auto-calculate weekly off days: any day not selected as a working day is automatically a weekly off day
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    _weeklyOffDays = allDays
        .where((day) => !(_availableDays ?? []).contains(day))
        .toList();

    setState(() => _isLoading = true);
    try {
      final updatedUser = await _nurseController.updateProfile(
        fullname: _nameController.text,
        mobile: _mobileController.text,
        bio: _bioController.text,
        qualification: _qualController.text,
        nursingRegistrationNumber: _nursingLicenseController.text,
        yearsOfExperience: _yearsExpController.text,
        workingDays: _availableDays ?? [],
        shiftStartTime: _slotStartController.text,
        shiftEndTime: _slotEndController.text,
        shiftType: _shiftTypeController.text,
        registrationCertificate: _regCertController.text,
        weeklyOffDays: _weeklyOffDays ?? [],
        specificLeaveDates: _specificLeaveDates ?? [],
      );

      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).updateUser(updatedUser);
        setState(() => _isEditingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0F5A8E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF718096)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateDisplayRow(String? certUrl) {
    final hasCert = certUrl != null && certUrl.isNotEmpty;
    final isUrl = hasCert && certUrl.startsWith('http');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Color(0xFF0F5A8E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Registration Certificate',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF718096)),
                ),
                const SizedBox(height: 2),
                if (isUrl)
                  InkWell(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final uri = Uri.parse(certUrl);
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Cannot open certificate: $e')),
                        );
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Certificate File',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.open_in_new_rounded, size: 14, color: Colors.blue),
                      ],
                    ),
                  )
                else
                  Text(
                    hasCert ? certUrl : 'No certificate uploaded',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateUploadField() {
    final certUrl = _regCertController.text;
    final hasCert = certUrl.isNotEmpty;
    final isUrl = hasCert && certUrl.startsWith('http');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registration Certificate Document',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isUrl
                      ? 'Certificate uploaded'
                      : (hasCert ? certUrl : 'No certificate uploaded yet'),
                  style: TextStyle(
                    color: isUrl ? Colors.green.shade800 : AppTheme.textSecondaryColor,
                    fontWeight: isUrl ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isUrl) ...[
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.blue, size: 20),
                  onPressed: () async {
                    final uri = Uri.parse(certUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() {
                      _regCertController.clear();
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
              _isUploadingCert
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : ElevatedButton.icon(
                      onPressed: _pickAndUploadCert,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                      label: const Text('Upload File', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.logoRed,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F5A8E)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileTextField(String label, TextEditingController controller, IconData icon, {bool isReadOnly = false, bool isNumeric = false, bool isAlphanumeric = false, int? maxLength, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLength: maxLength,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : (isReadOnly ? null : [
                  FilteringTextInputFormatter.allow(
                    isAlphanumeric 
                        ? RegExp(r'[a-zA-Z0-9\s./,()\-]') 
                        : RegExp(r'[a-zA-Z\s./,()\-]'),
                  ),
                ]),
          mouseCursor: onTap != null 
              ? SystemMouseCursors.click 
              : (isReadOnly ? SystemMouseCursors.forbidden : null),
          onTap: onTap,
          style: TextStyle(
            color: (isReadOnly && onTap == null) 
                ? AppTheme.textSecondaryColor.withOpacity(0.7) 
                : AppTheme.textPrimaryColor,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: label,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: AppTheme.iconColor),
            suffixIcon: (isReadOnly && onTap == null) ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey) : null,
            fillColor: isReadOnly ? const Color(0xFFF7FAFC) : Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && mounted) {
      controller.text = picked.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    if (_isEditingProfile) return _buildProfileEditView(isMobile);
    return _buildProfileDisplayView(isMobile);
  }

  Widget _buildProfileDisplayView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context).user;
    const sectionSpacing = SizedBox(height: 24);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overview of your professional details and settings',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditingProfile = true),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                      label: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                      style: AppTheme.primaryButton.copyWith(
                        backgroundColor: MaterialStateProperty.all(AppTheme.logoRed),
                        minimumSize: MaterialStateProperty.all(const Size(double.infinity, 44)),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile',
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Overview of your professional details and settings',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditingProfile = true),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                      label: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                      style: AppTheme.primaryButton.copyWith(
                        backgroundColor: MaterialStateProperty.all(AppTheme.logoRed),
                        minimumSize: MaterialStateProperty.all(const Size(0, 48)),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF1E3A8A)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(user?.rawFullname?.isNotEmpty == true ? user!.rawFullname![0].toUpperCase() : 'N', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.rawFullname ?? 'Nurse', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                          const SizedBox(height: 8),
                          Text(
                            user?.role ?? 'Nurse',
                            style: const TextStyle(
                              color: Color(0xFFC53030),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                 if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 20),
                  _buildDetailRow('Full Name', user?.rawFullname ?? '-', Icons.person_outline),
                  _buildDetailRow('Staff ID', user?.staffUniqueId ?? '-', Icons.badge_outlined),
                  _buildDetailRow('Email Address', user?.email ?? '-', Icons.alternate_email),
                  _buildDetailRow('Mobile Number', user?.mobile ?? '-', Icons.phone_android_outlined),
                  _buildDetailRow('Bio Summary', user?.bio ?? '-', Icons.description_outlined),
                ] else ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 20),
                  _buildDetailRow('Full Name', user?.rawFullname ?? '-', Icons.person_outline),
                  _buildDetailRow('Staff ID', user?.staffUniqueId ?? '-', Icons.badge_outlined),
                  _buildDetailRow('Email Address', user?.email ?? '-', Icons.alternate_email),
                  _buildDetailRow('Mobile Number', user?.mobile ?? '-', Icons.phone_android_outlined),
                ],
              ],
            ),
          ),
          sectionSpacing,
          _buildInfoCard('Professional Details', [
            _buildDetailRow('Qualification', user?.qualification ?? '-', Icons.school_outlined),
            _buildDetailRow('Nursing Registration Number', user?.nursingRegistrationNumber ?? '-', Icons.badge_outlined),
            _buildDetailRow(
              'Years of Experience',
              user?.yearsOfExperience == null || user?.yearsOfExperience == '0'
                  ? '-'
                  : '${user!.yearsOfExperience} years',
              Icons.work_history_outlined,
            ),
            _buildCertificateDisplayRow(user?.registrationCertificate),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileEditView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    const sectionSpacing = SizedBox(height: 24);
    const fieldSpacing = SizedBox(height: 16);

    Widget sectionCard(String number, String title, Color accentColor, List<Widget> fields) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: accentColor.withOpacity(0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(child: Text(number, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 24),
            ...fields,
          ],
        ),
      );
    }

    return StatefulBuilder(builder: (context, setLocalState) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             InkWell(
               onTap: () => setState(() => _isEditingProfile = false),
               borderRadius: BorderRadius.circular(8),
               child: const Padding(
                 padding: EdgeInsets.symmetric(vertical: 8),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(Icons.arrow_back, color: AppTheme.primaryColor, size: 16),
                     SizedBox(width: 8),
                     Text(
                       'Back to Profile',
                       style: TextStyle(
                         color: AppTheme.primaryColor,
                         fontSize: 13,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 20),
             const Text(
               'Update Profile',
               style: TextStyle(
                 fontSize: 28,
                 fontWeight: FontWeight.bold,
                 color: Colors.black,
               ),
             ),
             const SizedBox(height: 4),
             Text(
               'Modify your professional details and availability',
               style: const TextStyle(
                 color: Colors.black,
                 fontSize: 14,
               ),
             ),
             const SizedBox(height: 32),

            // ── Avatar + Basic Info ──────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user?.rawFullname?.isNotEmpty == true
                                ? user!.rawFullname![0].toUpperCase()
                                : 'N',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.rawFullname ?? 'Nurse',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.role ?? 'Nurse',
                            style: const TextStyle(
                              color: Color(0xFFC53030),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (isMobile) ...[
                    _buildProfileTextField('Full Name', _nameController, Icons.person_outline, isReadOnly: true),
                    fieldSpacing,
                    _buildProfileTextField('Email Address', _emailController, Icons.email_outlined, isReadOnly: true),
                    fieldSpacing,
                    _buildProfileTextField('Mobile Number', _mobileController, Icons.phone_android_outlined, isReadOnly: true),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField('Full Name', _nameController, Icons.person_outline, isReadOnly: true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField('Email Address', _emailController, Icons.email_outlined, isReadOnly: true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField('Mobile Number', _mobileController, Icons.phone_android_outlined, isReadOnly: true),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Text(
                         'Bio / Professional Summary',
                         style: TextStyle(
                           fontSize: 14,
                           fontWeight: FontWeight.bold,
                           color: Colors.black,
                         ),
                       ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                          LengthLimitingTextInputFormatter(300),
                        ],
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Share a brief summary of your expertise...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                          fillColor: AppTheme.backgroundColor,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            sectionSpacing,
            sectionCard('1', 'Professional Details', const Color(0xFF0D5D9A), [
              if (isMobile) ...[
                _buildProfileTextField('Qualification', _qualController, Icons.school_outlined),
                fieldSpacing,
                 _buildProfileTextField('Nursing Registration Number', _nursingLicenseController, Icons.badge_outlined, isAlphanumeric: true),
                fieldSpacing,
                _buildProfileTextField('Years of Experience', _yearsExpController, Icons.work_outline, isNumeric: true, maxLength: 2),
                fieldSpacing,
                _buildCertificateUploadField(),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildProfileTextField('Qualification', _qualController, Icons.school_outlined),
                    ),
                    const SizedBox(width: 16),
                     Expanded(
                       child: _buildProfileTextField('Nursing Registration Number', _nursingLicenseController, Icons.badge_outlined, isAlphanumeric: true),
                     ),
                  ],
                ),
                fieldSpacing,
                Row(
                  children: [
                    Expanded(
                      child: _buildProfileTextField('Years of Experience', _yearsExpController, Icons.work_outline, isNumeric: true, maxLength: 2),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox()), // Placeholder for balance
                  ],
                ),
                fieldSpacing,
                _buildCertificateUploadField(),
              ],
            ]),


            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _isEditingProfile = false),
                  style: AppTheme.cancelButton.copyWith(
                    minimumSize: MaterialStateProperty.all(const Size(120, 48)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.logoRed,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Profile Changes',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 24),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }
}
