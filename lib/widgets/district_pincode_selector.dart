import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/district_controller.dart';
import '../models/district_model.dart';
import '../utils/app_theme.dart';
import 'custom_dropdown_search.dart';

class DistrictPincodeSelector extends StatefulWidget {
  final String? initialDistrict;
  final String? initialPincode;
  final TextEditingController pincodeController;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onPincodeChanged;
  final bool isDesktop;
  final FormFieldValidator<String>? districtValidator;
  final FormFieldValidator<String>? pincodeValidator;
  final Widget Function(String label)? labelBuilder;

  const DistrictPincodeSelector({
    Key? key,
    this.initialDistrict,
    this.initialPincode,
    required this.pincodeController,
    required this.onDistrictChanged,
    required this.onPincodeChanged,
    this.isDesktop = false,
    this.districtValidator,
    this.pincodeValidator,
    this.labelBuilder,
  }) : super(key: key);

  @override
  State<DistrictPincodeSelector> createState() => _DistrictPincodeSelectorState();
}

class _DistrictPincodeSelectorState extends State<DistrictPincodeSelector> {
  final DistrictController _controller = DistrictController();

  List<String> _districts = [];
  List<PincodeModel> _pincodes = [];
  String? _selectedDistrict;
  String? _selectedPincode;
  bool _isLoadingDistricts = false;
  bool _isLoadingPincodes = false;
  String? _pincodeMessage;

  // Fallback default Tamil Nadu districts list
  static const List<String> _defaultTamilNaduDistricts = [
    'Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore',
    'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kancheepuram',
    'Kanyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai',
    'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai',
    'Ramanathapuram', 'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi',
    'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli',
    'Tirupathur', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur',
    'Vellore', 'Viluppuram', 'Virudhunagar',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.initialDistrict;
    _selectedPincode = widget.initialPincode;
    if (widget.initialPincode != null && widget.initialPincode!.isNotEmpty) {
      widget.pincodeController.text = widget.initialPincode!;
    }
    _loadDistricts();
  }

  @override
  void didUpdateWidget(covariant DistrictPincodeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDistrict != oldWidget.initialDistrict &&
        widget.initialDistrict != _selectedDistrict) {
      _selectedDistrict = widget.initialDistrict;
      if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
        _fetchPincodesForDistrict(_selectedDistrict!, preserveCurrentValue: true);
      }
    }
  }

  Future<void> _loadDistricts() async {
    setState(() => _isLoadingDistricts = true);
    try {
      final list = await _controller.fetchDistricts();
      if (mounted) {
        setState(() {
          _districts = list.isNotEmpty
              ? list.map((d) => d.name).toList()
              : _defaultTamilNaduDistricts;
          _isLoadingDistricts = false;
        });

        if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
          _fetchPincodesForDistrict(_selectedDistrict!, preserveCurrentValue: true);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _districts = _defaultTamilNaduDistricts;
          _isLoadingDistricts = false;
        });
      }
    }
  }

  Future<void> _fetchPincodesForDistrict(String district, {bool preserveCurrentValue = false}) async {
    setState(() {
      _isLoadingPincodes = true;
      _pincodeMessage = null;
      if (!preserveCurrentValue) {
        _selectedPincode = null;
        widget.pincodeController.clear();
        widget.onPincodeChanged(null);
      }
    });

    try {
      final list = await _controller.fetchPincodesForDistrict(district);
      if (!mounted) return;

      setState(() {
        _pincodes = list;
        _isLoadingPincodes = false;

        if (list.isEmpty) {
          _pincodeMessage = 'No PIN codes available for $district';
        } else if (list.length == 1) {
          // Exactly 1 PIN code: Auto-fill immediately
          final singlePin = list.first.pincode;
          _selectedPincode = singlePin;
          widget.pincodeController.text = singlePin;
          widget.onPincodeChanged(singlePin);
          _pincodeMessage = 'Auto-filled (${list.first.displayLabel})';
        } else {
          // Multiple PIN codes: dropdown available
          if (preserveCurrentValue && widget.pincodeController.text.isNotEmpty) {
            final existing = widget.pincodeController.text.trim();
            if (list.any((p) => p.pincode == existing)) {
              _selectedPincode = existing;
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPincodes = false;
          _pincodeMessage = 'Could not load PIN codes';
        });
      }
    }
  }

  void _onDistrictSelected(String? newDistrict) {
    if (newDistrict == _selectedDistrict) return;

    setState(() {
      _selectedDistrict = newDistrict;
    });

    widget.onDistrictChanged(newDistrict);

    if (newDistrict != null && newDistrict.trim().isNotEmpty) {
      _fetchPincodesForDistrict(newDistrict.trim(), preserveCurrentValue: false);
    } else {
      setState(() {
        _pincodes = [];
        _selectedPincode = null;
        widget.pincodeController.clear();
        _pincodeMessage = null;
      });
      widget.onPincodeChanged(null);
    }
  }

  Widget _buildLabel(String text) {
    if (widget.labelBuilder != null) {
      return widget.labelBuilder!(text);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildDistrictField() {
    final items = _districts.isNotEmpty ? _districts : _defaultTamilNaduDistricts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('District *'),
        CustomDropdownSearch(
          label: '',
          hint: 'Select district',
          dropdownItems: items,
          value: (_selectedDistrict != null && items.contains(_selectedDistrict))
              ? _selectedDistrict
              : null,
          onChanged: _onDistrictSelected,
          validator: widget.districtValidator ?? (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please select a valid District';
            }
            return null;
          },
          height: 52,
          fillColor: AppTheme.isDark(context)
              ? AppTheme.darkInputFillColor
              : const Color(0xFFF1F5F9),
          borderColor: AppTheme.getBorderColor(context),
          focusedBorderColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildPincodeField() {
    final isDark = AppTheme.isDark(context);
    final fillColor = isDark ? AppTheme.darkInputFillColor : const Color(0xFFF1F5F9);
    final borderColor = AppTheme.getBorderColor(context);

    // Case 1: Loading PIN codes
    if (_isLoadingPincodes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Pincode *'),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loading PIN codes for ${_selectedDistrict ?? "district"}...',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Case 2: District has multiple PIN codes -> Show searchable Dropdown
    if (_pincodes.length > 1) {
      final pinMap = <String, String>{
        for (var p in _pincodes) p.pincode: p.displayLabel,
      };

      final currentValue = (_selectedPincode != null && pinMap.containsKey(_selectedPincode))
          ? _selectedPincode
          : (pinMap.containsKey(widget.pincodeController.text.trim())
              ? widget.pincodeController.text.trim()
              : null);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Pincode *'),
          CustomDropdownSearch(
            label: '',
            hint: 'Select Pincode',
            dropdownMap: pinMap,
            value: currentValue,
            onChanged: (val) {
              setState(() {
                _selectedPincode = val;
                widget.pincodeController.text = val ?? '';
              });
              widget.onPincodeChanged(val);
            },
            validator: (val) {
              final clean = widget.pincodeController.text.trim();
              if (clean.isEmpty) {
                return 'Please select Pincode';
              }
              if (clean.length != 6) {
                return 'Pincode must be exactly 6 digits';
              }
              if (_pincodes.isNotEmpty && !_pincodes.any((p) => p.pincode == clean)) {
                return 'Selected PIN code does not belong to ${_selectedDistrict ?? "this district"}';
              }
              if (widget.pincodeValidator != null) {
                return widget.pincodeValidator!(clean);
              }
              return null;
            },
            height: 52,
            fillColor: fillColor,
            borderColor: borderColor,
            focusedBorderColor: AppTheme.primaryColor,
          ),
          if (_pincodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                '${_pincodes.length} PIN codes available for ${_selectedDistrict ?? "selected district"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
        ],
      );
    }

    // Case 3: District has exactly 1 PIN code (auto-filled) or fallback manual text entry
    final isAutoFilled = _pincodes.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Pincode *'),
        TextFormField(
          controller: widget.pincodeController,
          keyboardType: TextInputType.number,
          readOnly: isAutoFilled, // Auto-filled single pincode is safely locked or clear
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (val) {
            setState(() => _selectedPincode = val.trim());
            widget.onPincodeChanged(val.trim());
          },
          decoration: InputDecoration(
            hintText: _selectedDistrict == null ? 'Select district first' : 'Enter Pincode',
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            filled: true,
            fillColor: fillColor,
            suffixIcon: isAutoFilled
                ? Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Auto-filled',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
          validator: (val) {
            final clean = val?.trim() ?? '';
            if (clean.isEmpty) {
              return 'Please enter Pincode';
            }
            if (clean.length != 6) {
              return 'Pincode must be exactly 6 digits';
            }
            if (!clean.startsWith('6')) {
              return 'Please enter a valid Tamil Nadu Pincode (starts with 6)';
            }
            if (!RegExp(r'^6[0-4]\d{4}$').hasMatch(clean)) {
              return 'Please enter a valid Tamil Nadu Pincode (starts with 60-64)';
            }
            if (_pincodes.isNotEmpty && !_pincodes.any((p) => p.pincode == clean)) {
              return 'PIN code $clean does not belong to ${_selectedDistrict ?? "this district"}';
            }
            if (widget.pincodeValidator != null) {
              return widget.pincodeValidator!(clean);
            }
            return null;
          },
        ),
        if (_pincodeMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _pincodeMessage!,
              style: TextStyle(
                fontSize: 11,
                color: isAutoFilled ? Colors.green.shade700 : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDistrictField()),
          const SizedBox(width: 24),
          Expanded(child: _buildPincodeField()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDistrictField(),
        const SizedBox(height: 16),
        _buildPincodeField(),
      ],
    );
  }
}

