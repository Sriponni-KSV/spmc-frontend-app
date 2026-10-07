import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/home_visit_controller.dart';
import '../providers/language_provider.dart';
import '../services/live_speech_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';

class HomeVisitVoiceScribeDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const HomeVisitVoiceScribeDialog({
    super.key,
    this.initialData,
  });

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    final langLocale = Provider.of<LanguageProvider>(context, listen: false).locale;
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Localizations.override(
        context: dialogCtx,
        locale: langLocale,
        child: const HomeVisitVoiceScribeDialog(),
      ),
    );
  }

  @override
  State<HomeVisitVoiceScribeDialog> createState() =>
      _HomeVisitVoiceScribeDialogState();
}

class _HomeVisitVoiceScribeDialogState extends State<HomeVisitVoiceScribeDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _transcriptController = TextEditingController();
  final LiveSpeechService _speechService = LiveSpeechService();

  bool _isListening = false;
  bool _isAnalyzing = false;
  String _selectedLang = 'en-IN'; // 'en-IN' or 'ta-IN'
  String? _statusText;
  String? _errorMessage;
  Map<String, dynamic>? _extractedData;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize speech service
    _speechService.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transcriptController.dispose();
    _speechService.stopListening();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _errorMessage = null;
      _statusText = context.tr('listening', fallback: 'Listening...');
    });

    final success = await _speechService.startListening(
      lang: _selectedLang,
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _transcriptController.text = text;
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          if (status == 'listening') {
            _isListening = true;
            _statusText = context.tr('listening_speech', fallback: 'Listening to your voice...');
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
            _statusText = context.tr('speech_stopped', fallback: 'Dictation paused');
          }
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _errorMessage = err;
          _statusText = null;
        });
      },
    );

    if (mounted) {
      setState(() {
        _isListening = success;
        if (!success && _errorMessage == null) {
          _errorMessage = context.tr('mic_unavailable', fallback: 'Microphone not available or permission denied');
        }
      });
    }
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusText = context.tr('ready_to_analyze', fallback: 'Ready to analyze with AI');
      });
    }
  }

  Future<void> _runAiAnalysis() async {
    final text = _transcriptController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = context.tr('please_speak_or_type', fallback: 'Please speak or enter some clinical notes first.');
      });
      return;
    }

    final fallbackErrMsg = context.tr('ai_parse_failed', fallback: 'Failed to extract medical fields.');
    final ctrl = Provider.of<HomeVisitController>(context, listen: false);

    if (_isListening) {
      await _stopListening();
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await ctrl.parseDictation(text);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          if (result != null) {
            _extractedData = result;
          } else {
            _errorMessage = ctrl.errorMessage ?? fallbackErrMsg;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _applyData() {
    if (_extractedData != null) {
      Navigator.of(context).pop(_extractedData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        width: 650,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('ai_voice_scribe_title', fallback: 'AI Voice Scribe'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('ai_voice_scribe_desc', fallback: 'Speak visit notes once to auto-fill vitals, care, medicines, and consumables.'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Language Selector Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('speech_language', fallback: 'Speech Language:'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('English (India)'),
                      selected: _selectedLang == 'en-IN',
                      onSelected: _isListening
                          ? null
                          : (sel) {
                              if (sel) setState(() => _selectedLang = 'en-IN');
                            },
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedLang == 'en-IN' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedLang == 'en-IN' ? AppTheme.primaryColor : Colors.black87,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('தமிழ் (Tamil)'),
                      selected: _selectedLang == 'ta-IN',
                      onSelected: _isListening
                          ? null
                          : (sel) {
                              if (sel) setState(() => _selectedLang = 'ta-IN');
                            },
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedLang == 'ta-IN' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedLang == 'ta-IN' ? AppTheme.primaryColor : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mic Activation Area
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleListening,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _isListening ? _pulseAnimation.value : 1.0,
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _isListening
                                            ? [AppTheme.logoRed, const Color(0xFFF87171)]
                                            : [AppTheme.primaryColor, const Color(0xFF0D76BC)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_isListening ? AppTheme.logoRed : AppTheme.primaryColor)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isListening ? Icons.mic : Icons.mic_none,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isListening
                                ? context.tr('tap_mic_to_stop', fallback: 'Tap to Stop Dictation')
                                : context.tr('tap_mic_to_speak', fallback: 'Tap to Start Dictating'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isListening ? AppTheme.logoRed : AppTheme.primaryColor,
                            ),
                          ),
                          if (_statusText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _statusText!,
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dictation Transcript Box
                    Text(
                      context.tr('live_transcript_label', fallback: 'Spoken Transcript / Manual Notes:'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _transcriptController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.tr(
                          'voice_scribe_hint',
                          fallback: 'Example: Patient BP 120/80, pulse 76, sugar 140. Cleaned right foot ulcer with normal saline and applied gauze. Attender Lakshmi satisfied.',
                        ),
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.logoRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppTheme.logoRed),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(fontSize: 12, color: AppTheme.logoRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Results Preview Area if extracted
                    if (_extractedData != null) ...[
                      const SizedBox(height: 18),
                      _buildResultsPreview(_extractedData!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: AppTheme.cancelButton,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel', fallback: 'Cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                if (_extractedData == null)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButton,
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _isAnalyzing
                            ? context.tr('analyzing_notes', fallback: 'Analyzing with AI...')
                            : context.tr('extract_with_ai', fallback: 'Extract with AI'),
                      ),
                      onPressed: _isAnalyzing ? null : _runAiAnalysis,
                    ),
                  )
                else
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: AppTheme.secondaryButton,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(context.tr('apply_all_tabs', fallback: 'Apply to All Tabs')),
                      onPressed: _applyData,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPreview(Map<String, dynamic> data) {
    final vitals = data['vitals'] is Map ? Map<String, dynamic>.from(data['vitals'] as Map) : <String, dynamic>{};
    final care = data['care'] is Map ? Map<String, dynamic>.from(data['care'] as Map) : <String, dynamic>{};
    final rawCons = data['consumables'] as List<dynamic>? ?? [];
    final consumables = rawCons.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
    final rawMeds = data['medicines'] as List<dynamic>? ?? [];
    final medicines = rawMeds.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
    final attender = data['attender'] is Map ? Map<String, dynamic>.from(data['attender'] as Map) : <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, size: 18, color: AppTheme.secondaryColor),
              const SizedBox(width: 6),
              Text(
                context.tr('extracted_fields_preview', fallback: 'Extracted Fields Preview'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() => _extractedData = null);
                },
                child: Text(
                  context.tr('re_analyze', fallback: 'Re-analyze'),
                  style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Vitals chips
          if (vitals.isNotEmpty) ...[
            Text(
              context.tr('vitals', fallback: 'Vitals:'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (vitals['systolic_bp'] != null && vitals['diastolic_bp'] != null)
                  _buildChip('BP', '${vitals['systolic_bp']}/${vitals['diastolic_bp']} mmHg'),
                if (vitals['pulse'] != null)
                  _buildChip('Pulse', '${vitals['pulse']} bpm'),
                if (vitals['temperature'] != null)
                  _buildChip('Temp', '${vitals['temperature']} °F'),
                if (vitals['spo2'] != null)
                  _buildChip('SpO2', '${vitals['spo2']}%'),
                if (vitals['blood_sugar'] != null)
                  _buildChip('Sugar', '${vitals['blood_sugar']} mg/dL'),
                if (vitals['weight'] != null)
                  _buildChip('Weight', '${vitals['weight']} kg'),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Care notes
          if (care['dressing_notes'] != null || care['general_observations'] != null) ...[
            Text(
              context.tr('care_notes_label', fallback: 'Care & Observations:'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            if (care['dressing_notes'] != null)
              Text('• Dressing: ${care['dressing_notes']}', style: const TextStyle(fontSize: 11.5)),
            if (care['general_observations'] != null)
              Text('• Obs: ${care['general_observations']}', style: const TextStyle(fontSize: 11.5)),
            const SizedBox(height: 10),
          ],

          // Consumables
          if (consumables.isNotEmpty) ...[
            Text(
              context.tr('consumables_used_label', fallback: 'Consumables Used:'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: consumables.map((c) {
                return _buildChip(c['item_name']?.toString() ?? 'Item', 'Qty: ${c['quantity'] ?? 1}');
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Medicines
          if (medicines.isNotEmpty) ...[
            Text(
              context.tr('medicines_administered_label', fallback: 'Medicines Administered:'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: medicines.map((m) {
                return _buildChip(m['medicine_name']?.toString() ?? 'Med', 'Given');
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Attender
          if (attender['attender_name'] != null || attender['feedback'] != null) ...[
            Text(
              context.tr('attender_feedback_label', fallback: 'Attender:'),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 2),
            Text(
              '${attender['attender_name'] ?? 'Attender'} - ${attender['feedback'] ?? 'Satisfied'}',
              style: const TextStyle(fontSize: 11.5, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
