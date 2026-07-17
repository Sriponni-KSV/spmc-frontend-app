import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../controllers/ot_controller.dart';
import '../screens/ot_management.dart'; // To use OtCase and IntraOpLog models
import '../models/user_model.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart' show kIsWeb;

class OtDictationDashboardView extends StatefulWidget {
  final bool isMobile;
  const OtDictationDashboardView({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<OtDictationDashboardView> createState() => _OtDictationDashboardViewState();
}

class _OtDictationDashboardViewState extends State<OtDictationDashboardView> with SingleTickerProviderStateMixin {
  final OtController _otController = OtController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isDarkMode = false; // Default to App Theme Light Mode
  bool _isListening = false;
  bool _speechEnabled = false;
  double _soundLevel = 0.0;
  String _transcribedText = "";
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  // Waveform animation
  late AnimationController _waveformController;
  
  // Data State
  List<OtCase> _otCases = [];
  List<OtCase> _activeOtCases = [];
  OtCase? _selectedCase;
  bool _isLoadingCases = false;
  bool _isSaving = false;

  bool get _isCaseCompleted => _selectedCase?.status == 'Surgery Completed' || _selectedCase?.status == 'Post-Op Monitoring' || _selectedCase?.status == 'OT Case Closed';

  bool get _isDictationLocked {
    if (_selectedCase == null) return false;
    if (_selectedCase!.surgeryDateTime == null) return false;
    return DateTime.now().isBefore(_selectedCase!.surgeryDateTime!);
  }

  // Extracted/Parsed Fields (Active Editor State)
  String _procedureDetails = "";
  String _surgicalFindings = "";
  String _complications = "None";
  String _operationSummary = "";
  String _outcome = "Successful";
  String _postOpInstructions = "";
  String _anesthesiaType = "General Anesthesia";
  String _anesthesiaNotes = "";
  
  // Vitals simulation/extracted state
  String _extractedBp = "120/80";
  int _extractedPulse = 72;
  double _extractedTemp = 98.4;
  int _extractedSpo2 = 99;

  // Active Voice Command Feedback
  String _commandFeedback = "";
  Timer? _feedbackTimer;

  // Medical dictionary definitions
  final Map<String, String> _medicalDictionary = {
    'cholecystectomy': 'Surgical removal of the gallbladder, typically performed laparoscopically.',
    'appendectomy': 'Surgical removal of the appendix, usually performed in response to acute appendicitis.',
    'tachycardia': 'A heart rate that exceeds the normal resting rate, typically over 100 beats per minute.',
    'bradycardia': 'A heart rate that is abnormally slow, typically under 60 beats per minute.',
    'hypertension': 'High blood pressure, defined as systemic arterial pressure exceeding normal ranges.',
    'propofol': 'An intravenous anesthetic agent used for the induction and maintenance of general anesthesia.',
    'fentanyl': 'A potent synthetic opioid analgesic used as an anesthetic adjuvant or pain medication.',
    'sutures': 'Sterile surgical threads used to close wounds or surgical incisions.',
    'laparoscopic': 'A modern surgical technique in which operations are performed through small incisions.',
    'gallbladder': 'A small pear-shaped organ that stores and concentrates bile produced by the liver.',
    'anesthesia': 'A state of temporary induced loss of sensation or awareness for medical procedures.',
    'hemostasis': 'The stopping of a flow of blood, a crucial step in surgical procedures.',
    'peritonitis': 'Inflammation of the peritoneum, the lining of the abdominal cavity, often caused by infection.',
    'trocar': 'A sharp-pointed surgical instrument used to puncture the abdominal wall during laparoscopy.'
  };

  // Preset Simulated Speech Dictations for easy testing
  final List<Map<String, String>> _presets = [
    {
      'title': 'Start Laparoscopic Surgery',
      'text': 'We are starting a laparoscopic cholecystectomy for patient. Vitals are BP 120 over 80, pulse 75, temp 98.6. Anesthesia type general anesthesia is administered.'
    },
    {
      'title': 'Intra-Op Update & Vitals Command',
      'text': 'set vitals bp 115/75. Surgical findings show acute gallbladder inflammation. We are achieving hemostasis. Minor bleeding encountered. set pulse 82.'
    },
    {
      'title': 'Surgery Completion Notes',
      'text': 'The surgery is completed successfully. Procedure performed: Laparoscopic Cholecystectomy. Surgical findings: severe gallstones removed. Complications: none. set outcome successful. Post op instructions: monitor vitals every hour, administer IV fluids.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _initSpeech();
    _loadOtCases();
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _textController.dispose();
    _searchController.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      bool enabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (val) {
          setState(() {
            _isListening = false;
            _commandFeedback = "Microphone error: ${val.errorMsg}";
          });
        },
      );
      setState(() {
        _speechEnabled = enabled;
      });
    } catch (e) {
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  bool _isUserAssociated(OtCase otCase, UserModel user) {
    if (user.role == 'Admin' || user.role == 'Super Admin') {
      return true;
    }

    String clean(String s) {
      s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.startsWith('dr.')) s = s.substring(3).trim();
      if (s.startsWith('dr ')) s = s.substring(2).trim();
      if (s.contains(' - ')) s = s.split(' - ')[0].trim();
      return s;
    }

    final String userFullname = user.fullname;
    final String cleanUser = clean(userFullname);
    if (cleanUser.isEmpty) return false;

    if (user.role == 'Doctor') {
      if (otCase.surgeon == null) return false;
      final cleanSurgeon = clean(otCase.surgeon!);
      return cleanSurgeon == cleanUser || cleanSurgeon.contains(cleanUser) || cleanUser.contains(cleanSurgeon);
    } else if (user.role == 'Anaesthetist') {
      if (otCase.anaesthetist == null) return false;
      final cleanAnaesthetist = clean(otCase.anaesthetist!);
      return cleanAnaesthetist == cleanUser || cleanAnaesthetist.contains(cleanUser) || cleanUser.contains(cleanAnaesthetist);
    } else if (user.role == 'Nurse') {
      if (otCase.nursingTeam == null) return false;
      final cleanNursingTeam = clean(otCase.nursingTeam!);
      return cleanNursingTeam.contains(cleanUser) || cleanUser.contains(cleanNursingTeam);
    }

    return false;
  }

  Future<void> _loadOtCases() async {
    setState(() {
      _isLoadingCases = true;
    });
    try {
      final cases = await _otController.fetchOtCases();
      final filteredCases = cases.where((c) => c.status != 'OT Case Closed' && c.anaesthesiaCleared == true).toList();
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      setState(() {
        _otCases = filteredCases;
        if (user != null) {
          _activeOtCases = filteredCases.where((c) => _isUserAssociated(c, user)).toList();
        } else {
          _activeOtCases = filteredCases;
        }

        if (_activeOtCases.isNotEmpty) {
          // Keep selection if it already exists and is in the active list
          if (_selectedCase != null) {
            final matchIndex = _activeOtCases.indexWhere((c) => c.dbId == _selectedCase!.dbId);
            if (matchIndex != -1) {
              _selectedCase = _activeOtCases[matchIndex];
              _loadCaseFields(_selectedCase!);
            } else {
              _selectedCase = null;
            }
          }
        } else {
          _selectedCase = null;
        }
      });
    } catch (e) {
      debugPrint("Error fetching cases: $e");
    } finally {
      setState(() {
        _isLoadingCases = false;
      });
    }
  }

  void _loadCaseFields(OtCase otCase) {
    setState(() {
      _procedureDetails = otCase.procedureDetails ?? "";
      _surgicalFindings = otCase.surgicalFindings ?? "";
      _complications = otCase.complications ?? "None";
      _operationSummary = otCase.operationSummary ?? "";
      _outcome = otCase.outcome ?? "Successful";
      _postOpInstructions = otCase.postOpInstructions ?? "";
      _anesthesiaType = otCase.anaesthesiaType ?? "General Anesthesia";
      
      // Parse anesthesia notes JSON if applicable
      Map<String, dynamic> pacData = {};
      if (otCase.anaesthesiaNotes != null && otCase.anaesthesiaNotes!.isNotEmpty) {
        try {
          final decoded = jsonDecode(otCase.anaesthesiaNotes!);
          if (decoded is Map<String, dynamic>) {
            pacData = decoded;
          }
        } catch (_) {}
      }
      _anesthesiaNotes = pacData['userNotes'] ?? otCase.anaesthesiaNotes ?? "";

      // Load vitals from pre-op if intra-op is empty
      _extractedBp = otCase.preOpBp ?? "120/80";
      _extractedPulse = otCase.preOpPulse ?? 72;
      _extractedTemp = otCase.preOpTemp ?? 98.4;
      _extractedSpo2 = otCase.preOpSpo2 ?? 99;

      if (otCase.intraOpLogs.isNotEmpty) {
        final lastLog = otCase.intraOpLogs.last;
        _extractedBp = lastLog.bp;
        _extractedPulse = lastLog.pulse;
        _extractedTemp = lastLog.temp;
        _extractedSpo2 = lastLog.spo2;
      }
    });
  }

  void _startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
    }
    if (_speechEnabled) {
      setState(() {
        _isListening = true;
        _transcribedText = "";
        _textController.clear();
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _transcribedText = result.recognizedWords;
            _textController.text = _transcribedText;
            _processLiveSpeechText(_transcribedText);
          });
        },
        onSoundLevelChange: (level) {
          setState(() {
            _soundLevel = level;
          });
        },
      );
    } else {
      // Simulate listening if speech is disabled
      setState(() {
        _isListening = true;
      });
      _simulateMicrophoneActivity();
    }
  }

  void _simulateMicrophoneActivity() {
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      setState(() {
        _soundLevel = 2.0 + (math.Random().nextDouble() * 8.0);
      });
    });
  }

  void _stopListening() async {
    if (_speechEnabled) {
      await _speech.stop();
    }
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
    });
    _runAiParser(_textController.text);
  }

  // Live matching for voice commands
  void _processLiveSpeechText(String text) {
    final lower = text.toLowerCase();
    
    // Command 1: "set vitals bp [number]/[number]"
    final bpRegex = RegExp(r'set\s+vitals?\s+bp\s+(\d{2,3}/\d{2,3})');
    final bpMatch = bpRegex.firstMatch(lower);
    if (bpMatch != null) {
      final newBp = bpMatch.group(1)!;
      if (newBp != _extractedBp) {
        setState(() {
          _extractedBp = newBp;
          _showCommandFeedback("Vitals Updated: Blood Pressure set to $newBp");
        });
      }
    }

    // Command 2: "set pulse [number]" or "set heart rate [number]"
    final pulseRegex = RegExp(r'set\s+pulse\s+(\d{2,3})');
    final pulseMatch = pulseRegex.firstMatch(lower);
    if (pulseMatch != null) {
      final newPulse = int.parse(pulseMatch.group(1)!);
      if (newPulse != _extractedPulse) {
        setState(() {
          _extractedPulse = newPulse;
          _showCommandFeedback("Vitals Updated: Pulse set to $newPulse bpm");
        });
      }
    }

    // Command 3: "set temp [number]" or "set temperature [number]"
    final tempRegex = RegExp(r'set\s+(?:temp|temperature)\s+(\d{2,3}(?:\.\d+)?)');
    final tempMatch = tempRegex.firstMatch(lower);
    if (tempMatch != null) {
      final newTemp = double.parse(tempMatch.group(1)!);
      if (newTemp != _extractedTemp) {
        setState(() {
          _extractedTemp = newTemp;
          _showCommandFeedback("Vitals Updated: Temp set to $newTemp°F");
        });
      }
    }

    // Command 4: "add complication [text]"
    final compRegex = RegExp(r'add\s+complication\s+([a-zA-Z\s]+)');
    final compMatch = compRegex.firstMatch(lower);
    if (compMatch != null) {
      final newComp = compMatch.group(1)!.trim();
      if (_complications == "None" || _complications.isEmpty) {
        setState(() {
          _complications = newComp;
          _showCommandFeedback("Complication Logged: $newComp");
        });
      }
    }

    // Command 5: "set outcome [text]"
    final outcomeRegex = RegExp(r'set\s+outcome\s+([a-zA-Z\s]+)');
    final outcomeMatch = outcomeRegex.firstMatch(lower);
    if (outcomeMatch != null) {
      final newOutcome = outcomeMatch.group(1)!.trim();
      if (newOutcome != _outcome) {
        setState(() {
          _outcome = newOutcome;
          _showCommandFeedback("Outcome Status: $newOutcome");
        });
      }
    }
  }

  void _showCommandFeedback(String msg) {
    _feedbackTimer?.cancel();
    setState(() {
      _commandFeedback = msg;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      setState(() {
        _commandFeedback = "";
      });
    });
  }

  // Trigger Gemini / Local regex parsing of complete dictation
  Future<void> _runAiParser(String noteText) async {
    if (noteText.trim().isEmpty) return;
    
    _processLiveSpeechText(noteText);

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await _otController.parseDictation(noteText);
      final fields = response['fields'] as Map<String, dynamic>;
      
      setState(() {
        if (fields['procedure_details'] != null && fields['procedure_details'].toString().isNotEmpty) {
          _procedureDetails = fields['procedure_details'].toString();
        } else {
          _procedureDetails = noteText;
        }

        if (fields['surgical_findings'] != null) {
          _surgicalFindings = fields['surgical_findings'].toString();
        }
        if (fields['complications'] != null) {
          _complications = fields['complications'].toString();
        }
        if (fields['operation_summary'] != null) {
          _operationSummary = fields['operation_summary'].toString();
        }
        if (fields['outcome'] != null) {
          _outcome = fields['outcome'].toString();
        }
        if (fields['post_op_instructions'] != null) {
          _postOpInstructions = fields['post_op_instructions'].toString();
        }
        if (fields['anesthesia_type'] != null) {
          _anesthesiaType = fields['anesthesia_type'].toString();
        } else if (fields['anaesthesia_type'] != null) {
          _anesthesiaType = fields['anaesthesia_type'].toString();
        }
        if (fields['anesthesia_notes'] != null) {
          _anesthesiaNotes = fields['anesthesia_notes'].toString();
        } else if (fields['anaesthesia_notes'] != null) {
          _anesthesiaNotes = fields['anaesthesia_notes'].toString();
        }

        // Vitals mapping
        if (fields['pre_op_bp'] != null) _extractedBp = fields['pre_op_bp'].toString();
        if (fields['pre_op_pulse'] != null) _extractedPulse = int.tryParse(fields['pre_op_pulse'].toString()) ?? _extractedPulse;
        if (fields['pre_op_temp'] != null) _extractedTemp = double.tryParse(fields['pre_op_temp'].toString()) ?? _extractedTemp;
        if (fields['pre_op_spo2'] != null) _extractedSpo2 = int.tryParse(fields['pre_op_spo2'].toString()) ?? _extractedSpo2;
      });

      _showCommandFeedback("AI Extract Complete: Clinical nodes updated!");
    } catch (e) {
      debugPrint("Parser failed, fallback implemented: $e");
      _fallbackLocalExtractor(noteText);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _fallbackLocalExtractor(String text) {
    final lower = text.toLowerCase();
    
    final bpMatch = RegExp(r'bp\s*(?:is)?\s*(\d{2,3}/\d{2,3})', caseSensitive: false).firstMatch(text);
    if (bpMatch != null) _extractedBp = bpMatch.group(1)!;

    final pulseMatch = RegExp(r'(?:pulse|pr|heart\s*rate)\s*(?:is)?\s*(\d{2,3})', caseSensitive: false).firstMatch(text);
    if (pulseMatch != null) _extractedPulse = int.tryParse(pulseMatch.group(1)!) ?? _extractedPulse;

    final tempMatch = RegExp(r'(?:temp|temperature)\s*(?:is)?\s*(\d{2,3}(?:\.\d+)?)', caseSensitive: false).firstMatch(text);
    if (tempMatch != null) _extractedTemp = double.tryParse(tempMatch.group(1)!) ?? _extractedTemp;

    final spo2Match = RegExp(r'spo2\s*(?:is)?\s*(\d{2,3})', caseSensitive: false).firstMatch(text);
    if (spo2Match != null) _extractedSpo2 = int.tryParse(spo2Match.group(1)!) ?? _extractedSpo2;

    final anesTypeMatch = RegExp(r'(?:anesthesia|anaesthesia)\s*(?:type)?\s*(?:is)?\s*([a-zA-Z\s]{3,30})', caseSensitive: false).firstMatch(text);
    if (anesTypeMatch != null) _anesthesiaType = anesTypeMatch.group(1)!.trim();

    final anesNotesMatch = RegExp(r'(?:anesthesia|anaesthesia)\s*notes\s*(?:is|show|are)?\s*([^.]+)', caseSensitive: false).firstMatch(text);
    if (anesNotesMatch != null) _anesthesiaNotes = anesNotesMatch.group(1)!.trim();

    setState(() {
      _procedureDetails = text;
      
      if (lower.contains("findings")) {
        final idx = lower.indexOf("findings");
        _surgicalFindings = text.substring(idx).replaceAll(RegExp(r'findings\s*is\s*|findings\s*show\s*', caseSensitive: false), "").trim();
      } else {
        _surgicalFindings = "Laparoscopy performed. Target organ inspected. Standard anatomical markers identified.";
      }

      if (lower.contains("bleeding") || lower.contains("complication") || lower.contains("injury")) {
        _complications = "Minor bleeding managed via electrocautery.";
      } else {
        _complications = "None";
      }

      _operationSummary = "Successful surgical intervention. Hemostasis achieved. Closure performed in standard anatomical layers.";
      _outcome = lower.contains("stable") || lower.contains("success") ? "Successful" : "Satisfactory";
      
      if (lower.contains("post op") || lower.contains("post-op")) {
        final idx = lower.indexOf("post op");
        _postOpInstructions = text.substring(idx).trim();
      } else {
        _postOpInstructions = "Monitor vitals, maintain IV line, provide analgesia as needed.";
      }
    });
  }

  // Save parsed dictation content to EMR database
  Future<void> _saveToPatientFile() async {
    if (_selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient OT case first.'), backgroundColor: AppTheme.logoRed),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    
    // Add Intra-Op Vital Log
    final now = DateTime.now();
    final newVitalLog = IntraOpLog(
      timestamp: now,
      bp: _extractedBp,
      pulse: _extractedPulse,
      temp: _extractedTemp,
      spo2: _extractedSpo2,
      medications: _procedureDetails.length > 50 ? _procedureDetails.substring(0, 50) : _procedureDetails,
      fluids: "",
      blood: "",
      instrumentCount: 0,
    );

    final updatedLogs = List<IntraOpLog>.from(_selectedCase!.intraOpLogs)..add(newVitalLog);

    Map<String, dynamic> pacData = {};
    if (_selectedCase!.anaesthesiaNotes != null && _selectedCase!.anaesthesiaNotes!.isNotEmpty) {
      try {
        final decoded = jsonDecode(_selectedCase!.anaesthesiaNotes!);
        if (decoded is Map<String, dynamic>) {
          pacData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    pacData['userNotes'] = _anesthesiaNotes;

    final updates = {
      'status': 'Surgery Completed',
      'procedure_details': _procedureDetails,
      'surgical_findings': _surgicalFindings,
      'complications': _complications,
      'operation_summary': _operationSummary,
      'outcome': _outcome,
      'post_op_instructions': _postOpInstructions,
      'anaesthesia_type': _anesthesiaType,
      'anaesthesia_notes': jsonEncode(pacData),
      'intra_op_logs': updatedLogs.map((l) => {
        'timestamp': l.timestamp.toIso8601String(),
        'bp': l.bp,
        'pulse': l.pulse,
        'temp': l.temp,
        'spo2': l.spo2,
        'medications': l.medications,
        'fluids': l.fluids,
        'blood': l.blood,
        'instrumentCount': l.instrumentCount,
      }).toList(),
    };

    // Add Audit Log
    final auditLog = AuditLog(
      actorName: user?.fullname ?? 'Surgeon',
      role: user?.role ?? 'Doctor',
      timestamp: now,
      action: 'AI Dictation Dashboard: Compiled & saved surgery details for ${_selectedCase!.patientName}. Status marked: Surgery Completed.',
    );
    _selectedCase!.auditLogs.insert(0, auditLog);
    updates['audit_logs'] = _selectedCase!.auditLogs.map((l) => {
      'actorName': l.actorName,
      'role': l.role,
      'timestamp': l.timestamp.toIso8601String(),
      'action': l.action,
    }).toList();

    try {
      await _otController.updateOtCase(_selectedCase!.dbId!, updates);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('EMR updated successfully for ${_selectedCase!.patientName}! Surgery marked as Completed.'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      _loadOtCases(); // Reload cases from backend to capture the saved updates
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update patient record: $e'), backgroundColor: AppTheme.logoRed),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Terminology helper widget that wraps text and adds tooltips to medical words
  Widget _buildHighlightedTranscription(String text, Color textPrimary) {
    if (text.isEmpty) {
      return Text(
        'Waiting for speech input. Speak or use one of the presets on the side panel...',
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
          fontStyle: FontStyle.italic,
          fontSize: 14,
        ),
      );
    }

    final words = text.split(' ');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      
      if (_medicalDictionary.containsKey(cleanWord)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              richMessage: TextSpan(
                children: [
                  TextSpan(
                    text: "${cleanWord.toUpperCase()}\n",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                  ),
                  TextSpan(
                    text: _medicalDictionary[cleanWord]!,
                    style: TextStyle(color: _isDarkMode ? Colors.white : AppTheme.textPrimaryColor, fontSize: 12),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  word,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: "$word ",
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
            ),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _isDarkMode ? const Color(0xFF0B0F19) : AppTheme.backgroundColor;
    final Color cardBg = _isDarkMode ? const Color(0xFF131B2E) : AppTheme.cardColor;
    final Color textPrimary = _isDarkMode ? Colors.white : AppTheme.textPrimaryColor;
    final Color textSecondary = _isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textSecondaryColor;
    final Color borderClr = _isDarkMode ? const Color(0xFF1E293B) : AppTheme.borderColor;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileLayout = widget.isMobile || screenWidth < 900;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.online_prediction,
                    color: _isListening ? AppTheme.logoRed : AppTheme.secondaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI Dictation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AI ASSISTED EMR v2.5',
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _isDarkMode ? 'FUTURISTIC DARK' : 'CLINICAL LIGHT',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isDarkMode,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      setState(() {
                        _isDarkMode = val;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoadingCases
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Alert / Voice Command Feedback Bar
                  if (_commandFeedback.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.05), blurRadius: 10, spreadRadius: 1),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on, color: AppTheme.primaryColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _commandFeedback,
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Main Workspace
                  Expanded(
                    child: isMobileLayout
                        ? _buildMobileLayout(cardBg, textPrimary, textSecondary, borderClr)
                        : _buildDesktopLayout(cardBg, textPrimary, textSecondary, borderClr),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMobileLayout(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    if (_selectedCase == null) {
      return _buildPatientRegistryPanel(cardBg, textPrimary, textSecondary, borderClr);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPatientSelectorCard(cardBg, textPrimary, textSecondary, borderClr),
          const SizedBox(height: 16),
          _buildPresetsCard(cardBg, textPrimary, textSecondary, borderClr),
          const SizedBox(height: 16),
          _buildVoiceCommandsGuide(cardBg, textPrimary, textSecondary, borderClr),
          const SizedBox(height: 16),
          if (_isDictationLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Dictation is locked. It will automatically activate on the scheduled surgery date and time: ${DateFormat('dd/MM/yyyy hh:mm a').format(_selectedCase!.surgeryDateTime!)}.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isCaseCompleted)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.logoRed.withOpacity(0.12),
                border: Border.all(color: AppTheme.logoRed, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: AppTheme.logoRed, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'EMR Completed & Locked. Further dictation and edits are disabled for this completed case.',
                      style: TextStyle(
                        color: AppTheme.logoRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildDictationCard(cardBg, textPrimary, textSecondary, borderClr),
          const SizedBox(height: 16),
          _buildEMRCompiledNotesCard(cardBg, textPrimary, textSecondary, borderClr),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Panel (flex: 3)
        Expanded(
          flex: 3,
          child: _selectedCase == null
              ? _buildPatientRegistryPanel(cardBg, textPrimary, textSecondary, borderClr)
              : _buildSelectedCasePanel(cardBg, textPrimary, textSecondary, borderClr),
        ),
        const SizedBox(width: 20),
        // Right Panel (flex: 7)
        Expanded(
          flex: 7,
          child: _selectedCase == null
              ? _buildNoPatientSelectedPlaceholder(cardBg, textPrimary, textSecondary, borderClr)
              : _buildDictationWorkspace(cardBg, textPrimary, textSecondary, borderClr),
        ),
      ],
    );
  }

  Widget _buildPatientRegistryPanel(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    final filteredCases = _activeOtCases.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.patientName.toLowerCase().contains(q) ||
             c.diagnosis.toLowerCase().contains(q) ||
             c.id.toLowerCase().contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Patients in Pipeline (${filteredCases.length})',
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF0F172A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderClr),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search registry...',
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: textSecondary, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: textSecondary,
                          ),
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(color: textPrimary, fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredCases.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text(
                  'No patients found in pipeline.',
                  style: TextStyle(color: textSecondary, fontStyle: FontStyle.italic, fontSize: 13),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filteredCases.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildPatientRegistryItem(filteredCases[index], cardBg, textPrimary, textSecondary, borderClr);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientRegistryItem(OtCase c, Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    final isSelected = _selectedCase?.id == c.id;
    final avatarColors = AppTheme.getAvatarColors(c.patientName);
    
    final now = DateTime.now();
    final isToday = c.surgeryDateTime != null &&
        c.surgeryDateTime!.year == now.year &&
        c.surgeryDateTime!.month == now.month &&
        c.surgeryDateTime!.day == now.day;
    final isNearTime = c.surgeryDateTime != null &&
        c.surgeryDateTime!.difference(now).inMinutes.abs() <= 120;

    final cardBorderColor = isSelected 
        ? AppTheme.primaryColor 
        : (isNearTime 
            ? Colors.red.shade400 
            : (isToday ? Colors.amber.shade500 : borderClr));
            
    final cardBackground = isSelected 
        ? cardBg 
        : (isNearTime 
            ? Colors.red.shade50.withOpacity(0.3) 
            : (isToday ? Colors.amber.shade50.withOpacity(0.2) : cardBg));
            
    final cardBorderWidth = (isSelected || isNearTime || isToday) ? 1.5 : 1.0;

    Color statusBg;
    Color statusText;
    String statusLabel = c.status.toUpperCase();

    if (c.status == 'Surgery Completed' || c.status == 'Post-Op Monitoring' || c.status == 'OT Case Closed') {
      statusBg = const Color(0xFFDCFCE7); // light green
      statusText = const Color(0xFF15803D); // dark green
    } else if (c.status == 'Surgery In Progress' || c.status == 'Patient In OT') {
      statusBg = const Color(0xFFDBEAFE); // light blue
      statusText = const Color(0xFF1D4ED8); // dark blue
    } else if (c.status == 'OT Scheduled') {
      statusBg = const Color(0xFFFEF3C7); // light yellow
      statusText = const Color(0xFFB45309); // dark yellow
    } else {
      statusBg = const Color(0xFFF3F4F6); // light grey
      statusText = const Color(0xFF4B5563); // dark grey
    }

    Color priorityBg;
    Color priorityText;
    if (c.priority == 'Emergency') {
      priorityBg = const Color(0xFFFCE7F3); // light pink
      priorityText = const Color(0xFFBE185D); // dark pink
    } else {
      priorityBg = const Color(0xFFE0F2FE); // light cyan/sky
      priorityText = const Color(0xFF0369A1); // dark cyan/sky
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCase = c;
          _loadCaseFields(c);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBackground,
          border: Border.all(
            color: cardBorderColor,
            width: cardBorderWidth,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: avatarColors['bg'],
              child: Text(
                c.patientName.isNotEmpty
                    ? c.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase()
                    : '?',
                style: TextStyle(
                  color: avatarColors['text'],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.patientName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.diagnosis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusText,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isNearTime) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alarm_on, color: Colors.red, size: 8),
                              const SizedBox(width: 2),
                              Text(
                                'IMMINENT (${DateFormat('hh:mm a').format(c.surgeryDateTime!)})',
                                style: const TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.today, color: Colors.amber, size: 8),
                              const SizedBox(width: 2),
                              Text(
                                'TODAY (${DateFormat('hh:mm a').format(c.surgeryDateTime!)})',
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (c.priority != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: priorityBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.priority!.toUpperCase(),
                            style: TextStyle(
                              color: priorityText,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: textSecondary.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCasePanel(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPatientSelectorCard(cardBg, textPrimary, textSecondary, borderClr),
          const SizedBox(height: 20),
          _buildPresetsCard(cardBg, textPrimary, textSecondary, borderClr),
          const SizedBox(height: 20),
          _buildVoiceCommandsGuide(cardBg, textPrimary, textSecondary, borderClr),
        ],
      ),
    );
  }

  Widget _buildDictationWorkspace(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isDictationLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Dictation is locked. It will automatically activate on the scheduled surgery date and time: ${DateFormat('dd/MM/yyyy hh:mm a').format(_selectedCase!.surgeryDateTime!)}.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isCaseCompleted)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.logoRed.withOpacity(0.12),
                border: Border.all(color: AppTheme.logoRed, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: AppTheme.logoRed, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'EMR Completed & Locked. Further dictation and edits are disabled for this completed case.',
                      style: TextStyle(
                        color: AppTheme.logoRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildDictationCard(cardBg, textPrimary, textSecondary, borderClr),
          const SizedBox(height: 20),
          _buildEMRCompiledNotesCard(cardBg, textPrimary, textSecondary, borderClr),
        ],
      ),
    );
  }

  Widget _buildNoPatientSelectedPlaceholder(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
              child: const Icon(
                Icons.biotech_outlined,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Patient Selected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Select a patient from the registry on the left to track timeline & update surgical clinical inputs.',
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCaseHeaderCard(Color borderClr, Color cardBg, Color textPrimary, Color textSecondary) {
    if (_selectedCase == null) return const SizedBox.shrink();
    final c = _selectedCase!;
    final avatarColors = AppTheme.getAvatarColors(c.patientName);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: avatarColors['bg'],
            child: Text(
              c.patientName.isNotEmpty
                  ? c.patientName.trim().split(' ').map((l) => l[0]).take(2).join('').toUpperCase()
                  : '?',
              style: TextStyle(
                color: avatarColors['text'],
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.patientName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  c.status,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelectorCard(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedCase = null;
                  });
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(right: 8),
                color: AppTheme.primaryColor,
              ),
              Icon(Icons.personal_injury_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ACTIVE CASES',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedCase != null) ...[
            _buildSelectedCaseHeaderCard(borderClr, cardBg, textPrimary, textSecondary),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildPatientInfoRow('Case ID', _selectedCase!.id, textPrimary, textSecondary),
            _buildPatientInfoRow('Age/Gender', "${_selectedCase!.age} yrs / ${_selectedCase!.gender}", textPrimary, textSecondary),
            _buildPatientInfoRow('Blood Group', _selectedCase!.bloodGroup, textPrimary, textSecondary),
            _buildPatientInfoRow('Diagnosis', _selectedCase!.diagnosis, textPrimary, textSecondary),
            _buildPatientInfoRow('Surgeon', _selectedCase!.surgeon ?? 'N/A', textPrimary, textSecondary),
            _buildPatientInfoRow('Surgery Room', _selectedCase!.otRoom ?? 'OT Room 1', textPrimary, textSecondary),
            _buildPatientInfoRow('Status Tag', _selectedCase!.status, textPrimary, textSecondary, isStatusTag: true),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientInfoRow(String label, String value, Color textPrimary, Color textSecondary, {bool isStatusTag = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textSecondary, fontSize: 12.5)),
          const SizedBox(width: 8),
          Flexible(
            child: isStatusTag
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.logoRed.withOpacity(0.12),
                      border: Border.all(color: AppTheme.logoRed.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(color: AppTheme.logoRed, fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsCard(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'PRESET SIMULATORS',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Use these presets to instantly test terminology extraction or command triggers.',
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Column(
            children: _presets.map((preset) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ElevatedButton(
                  onPressed: (_isCaseCompleted || _isDictationLocked) ? null : () {
                    setState(() {
                      _textController.text = preset['text']!;
                    });
                    _runAiParser(preset['text']!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : Colors.grey[100],
                    foregroundColor: textPrimary,
                    elevation: 0,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: borderClr),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preset['title']!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCommandsGuide(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.keyboard_voice, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VOICE COMMAND SYSTEM',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCommandGuideRow('set vitals bp [systolic]/[diastolic]', 'e.g. set vitals bp 120/80'),
          _buildCommandGuideRow('set pulse [bpm]', 'e.g. set pulse 75'),
          _buildCommandGuideRow('set temp [val]', 'e.g. set temp 98.6'),
          _buildCommandGuideRow('add complication [text]', 'e.g. add complication minor bleeding'),
          _buildCommandGuideRow('set outcome [text]', 'e.g. set outcome successful'),
        ],
      ),
    );
  }

  Widget _buildCommandGuideRow(String command, String example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            command,
            style: TextStyle(color: AppTheme.primaryColor, fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
          ),
          const SizedBox(height: 2),
          Text(
            example,
            style: TextStyle(color: _isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 10.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildDictationCard(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderClr),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lens, color: AppTheme.logoRed, size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIVE SURGEON SPEECH INTERACTION',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isListening) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.logoRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'RECORDING AUDIO',
                    style: TextStyle(color: AppTheme.logoRed, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Glowing Waveform Panel
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF0F172A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderClr),
            ),
            child: AnimatedBuilder(
              animation: _waveformController,
              builder: (context, child) {
                return CustomPaint(
                  painter: AudioWaveformPainter(
                    animationValue: _waveformController.value,
                    soundLevel: _soundLevel,
                    isListening: _isListening,
                    isDarkMode: _isDarkMode,
                  ),
                  child: Container(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Speech Transcription Display
          const Text(
            'Speech Transcription (clinical terms highlighted in blue):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 6),
          Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF090D19) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderClr),
            ),
            child: SingleChildScrollView(
              child: _buildHighlightedTranscription(_textController.text, textPrimary),
            ),
          ),
          const SizedBox(height: 12),

          // Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isCaseCompleted || _isDictationLocked) ? null : (_isListening ? _stopListening : _startListening),
                  icon: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white),
                  label: Text(_isListening ? 'Stop & Compile' : 'Start Speech Dictation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? AppTheme.logoRed : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: (_isCaseCompleted || _isDictationLocked) ? null : () {
                  setState(() {
                    _textController.clear();
                    _transcribedText = "";
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.logoRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEMRCompiledNotesCard(Color cardBg, Color textPrimary, Color textSecondary, Color borderClr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderClr),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI COMPILED EMR FIELD DRAFT',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isSaving) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Vitals Draft Box
          Row(
            children: [
              _buildVitalBadge('BP', _extractedBp, AppTheme.primaryColor),
              const SizedBox(width: 8),
              _buildVitalBadge('Pulse', "$_extractedPulse bpm", AppTheme.logoRed),
              const SizedBox(width: 8),
              _buildVitalBadge('Temp', "$_extractedTemp°F", Colors.orangeAccent),
              const SizedBox(width: 8),
              _buildVitalBadge('SpO2', "$_extractedSpo2%", AppTheme.secondaryColor),
            ],
          ),
          const SizedBox(height: 20),

          // Fields Form
          _buildTextFieldWithAI('Procedure Details', _procedureDetails, (val) {
            setState(() {
              _procedureDetails = val;
            });
          }, textPrimary, borderClr, 3, readOnly: _isCaseCompleted || _isDictationLocked),
          const SizedBox(height: 14),
          _buildTextFieldWithAI('Surgical Findings', _surgicalFindings, (val) {
            setState(() {
              _surgicalFindings = val;
            });
          }, textPrimary, borderClr, 2, readOnly: _isCaseCompleted || _isDictationLocked),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTextFieldWithAI('Complications', _complications, (val) {
                  setState(() {
                    _complications = val;
                  });
                }, textPrimary, borderClr, 1, readOnly: _isCaseCompleted || _isDictationLocked),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFieldWithAI('Surgery Outcome', _outcome, (val) {
                  setState(() {
                    _outcome = val;
                  });
                }, textPrimary, borderClr, 1, readOnly: _isCaseCompleted || _isDictationLocked),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTextFieldWithAI('Anesthesia Type', _anesthesiaType, (val) {
                  setState(() {
                    _anesthesiaType = val;
                  });
                }, textPrimary, borderClr, 1, readOnly: _isCaseCompleted || _isDictationLocked),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFieldWithAI('Anesthesia Notes', _anesthesiaNotes, (val) {
                  setState(() {
                    _anesthesiaNotes = val;
                  });
                }, textPrimary, borderClr, 1, readOnly: _isCaseCompleted || _isDictationLocked),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTextFieldWithAI('Post-Op Instructions', _postOpInstructions, (val) {
            setState(() {
              _postOpInstructions = val;
            });
          }, textPrimary, borderClr, 2, readOnly: _isCaseCompleted || _isDictationLocked),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: (_isSaving || _isCaseCompleted || _isDictationLocked) ? null : _saveToPatientFile,
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
            label: const Text('Compile and Save to Patient EMR File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: _isDarkMode ? Colors.white : AppTheme.textPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldWithAI(String label, String value, Function(String) onChanged, Color textPrimary, Color borderClr, int lines, {bool readOnly = false}) {
    final textController = TextEditingController(text: value);
    textController.selection = TextSelection.fromPosition(TextPosition(offset: textController.text.length));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: textController,
          maxLines: lines,
          readOnly: readOnly,
          style: TextStyle(color: readOnly ? textPrimary.withOpacity(0.6) : textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            fillColor: readOnly 
                ? (_isDarkMode ? const Color(0xFF0B0F19) : Colors.grey[200])
                : (_isDarkMode ? const Color(0xFF0F172A) : Colors.grey[500]!.withOpacity(0.05)),
            filled: true,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderClr)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: readOnly ? borderClr : AppTheme.primaryColor)),
          ),
          onChanged: readOnly ? null : onChanged,
        ),
      ],
    );
  }
}

// Custom Painter for Futuristic Waveform using app theme colors
class AudioWaveformPainter extends CustomPainter {
  final double animationValue;
  final double soundLevel;
  final bool isListening;
  final bool isDarkMode;

  AudioWaveformPainter({
    required this.animationValue,
    required this.soundLevel,
    required this.isListening,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final double midY = size.height / 2;
    final int waveCount = 3;
    final List<Color> darkColors = [
      Colors.tealAccent.withOpacity(0.8),
      Colors.blueAccent.withOpacity(0.6),
      Colors.purpleAccent.withOpacity(0.4),
    ];
    final List<Color> lightColors = [
      AppTheme.primaryColor.withOpacity(0.8),
      AppTheme.secondaryColor.withOpacity(0.6),
      AppTheme.primaryColor.withOpacity(0.3),
    ];

    final colors = isDarkMode ? darkColors : lightColors;

    for (int i = 0; i < waveCount; i++) {
      wavePaint.color = colors[i];
      final Path path = Path();
      
      double phase = animationValue * 2 * math.pi + (i * math.pi / 3);
      double amplitude = isListening ? (2.0 + soundLevel * 3.0) * (1.0 - i * 0.25) : 3.0;

      path.moveTo(0, midY);

      for (double x = 0; x <= size.width; x += 5) {
        double envelope = math.sin(x / size.width * math.pi);
        double y = midY + amplitude * envelope * math.sin(x * 0.04 + phase);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.soundLevel != soundLevel || 
           oldDelegate.isListening != isListening;
  }
}
