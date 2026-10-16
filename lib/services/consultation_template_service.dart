import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsultationTemplate {
  final String id;
  final String title;
  final String specialty;
  final String complaint;
  final String examination;
  final String diagnosis;
  final String? icd10Code;
  final List<String> investigations;
  final List<Map<String, String>> medications;
  final String clinicalNotes;
  final String? treatmentPlan;
  final bool isCustom;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final double? sugarLevel;
  final double? temperature;
  final int? pulse;
  final int? spo2;

  const ConsultationTemplate({
    required this.id,
    required this.title,
    required this.specialty,
    required this.complaint,
    required this.examination,
    required this.diagnosis,
    this.icd10Code,
    this.investigations = const [],
    this.medications = const [],
    required this.clinicalNotes,
    this.treatmentPlan,
    this.isCustom = false,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.sugarLevel,
    this.temperature,
    this.pulse,
    this.spo2,
  });

  int? get effectiveSystolic {
    if (bloodPressureSystolic != null) return bloodPressureSystolic;
    final match = RegExp(
      r'(?:BP|Blood\s*Pressure)[:\s]*([0-9]{2,3})\s*[/]\s*([0-9]{2,3})',
      caseSensitive: false,
    ).firstMatch('$examination $complaint');
    if (match != null) {
      final v = int.tryParse(match.group(1) ?? '');
      if (v != null && v >= 90 && v <= 300) return v;
    }
    return null;
  }

  int? get effectiveDiastolic {
    if (bloodPressureDiastolic != null) return bloodPressureDiastolic;
    final match = RegExp(
      r'(?:BP|Blood\s*Pressure)[:\s]*([0-9]{2,3})\s*[/]\s*([0-9]{2,3})',
      caseSensitive: false,
    ).firstMatch('$examination $complaint');
    if (match != null) {
      final v = int.tryParse(match.group(2) ?? '');
      if (v != null && v >= 50 && v <= 180) return v;
    }
    return null;
  }

  double? get effectiveTemperature {
    if (temperature != null) return temperature;
    final match = RegExp(
      r'(?:(?<!a)febrile[\s:\(]*([0-9]{2,3}(?:\.[0-9]+)?)\s*°?\s*F|temp(?:erature)?[:\s]*([0-9]{2,3}(?:\.[0-9]+)?)\s*°?\s*F)',
      caseSensitive: false,
    ).firstMatch('$examination $complaint');
    if (match != null) {
      final str = match.group(1) ?? match.group(2) ?? '';
      final v = double.tryParse(str);
      if (v != null && v >= 90 && v <= 115) return v;
    }
    return null;
  }

  int? get effectivePulse {
    if (pulse != null) return pulse;
    final match = RegExp(
      r'(?:Pulse|Heart\s*Rate|HR)[:\s]*([0-9]{2,3})',
      caseSensitive: false,
    ).firstMatch('$examination $complaint');
    if (match != null) {
      final v = int.tryParse(match.group(1) ?? '');
      if (v != null && v >= 40 && v <= 220) return v;
    }
    return null;
  }

  double? get effectiveSugar {
    if (sugarLevel != null) return sugarLevel;
    final match = RegExp(
      r'(?:Sugar|RBS|FBS|PPBS|Glucose)[:\s]*([0-9]{2,3}(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch('$examination $complaint');
    if (match != null) {
      final v = double.tryParse(match.group(1) ?? '');
      if (v != null && v >= 30 && v <= 600) return v;
    }
    return null;
  }

  int? get effectiveSpo2 {
    if (spo2 != null) return spo2;
    final match = RegExp(
      r'(?:SPO2|SpO2|Oxygen\s*Saturation)[:\s]*([0-9]{2,3})\s*%',
      caseSensitive: false,
    ).firstMatch('$examination $complaint');
    if (match != null) {
      final v = int.tryParse(match.group(1) ?? '');
      if (v != null && v >= 50 && v <= 100) return v;
    }
    return null;
  }

  bool get hasVitals =>
      effectiveSystolic != null ||
      effectiveDiastolic != null ||
      effectiveTemperature != null ||
      effectivePulse != null ||
      effectiveSugar != null ||
      effectiveSpo2 != null;

  String get vitalsSummary {
    final parts = <String>[];
    if (effectiveSystolic != null && effectiveDiastolic != null) {
      parts.add('BP: $effectiveSystolic/$effectiveDiastolic mmHg');
    }
    if (effectiveTemperature != null) {
      parts.add('Temp: $effectiveTemperature°F');
    }
    if (effectivePulse != null) {
      parts.add('Pulse: $effectivePulse bpm');
    }
    if (effectiveSugar != null) {
      parts.add('Sugar: $effectiveSugar mg/dL');
    }
    if (effectiveSpo2 != null) {
      parts.add('SpO2: $effectiveSpo2%');
    }
    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'specialty': specialty,
        'complaint': complaint,
        'examination': examination,
        'diagnosis': diagnosis,
        'icd10Code': icd10Code,
        'investigations': investigations,
        'medications': medications,
        'clinicalNotes': clinicalNotes,
        'treatmentPlan': treatmentPlan,
        'isCustom': isCustom,
        'bloodPressureSystolic': bloodPressureSystolic,
        'bloodPressureDiastolic': bloodPressureDiastolic,
        'sugarLevel': sugarLevel,
        'temperature': temperature,
        'pulse': pulse,
        'spo2': spo2,
      };

  factory ConsultationTemplate.fromJson(Map<String, dynamic> json) {
    return ConsultationTemplate(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      specialty: json['specialty'] ?? 'General Medicine',
      complaint: json['complaint'] ?? '',
      examination: json['examination'] ?? '',
      diagnosis: json['diagnosis'] ?? '',
      icd10Code: json['icd10Code'],
      investigations: (json['investigations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          const [],
      clinicalNotes: json['clinicalNotes'] ?? '',
      treatmentPlan: json['treatmentPlan'],
      isCustom: json['isCustom'] ?? false,
      bloodPressureSystolic: json['bloodPressureSystolic'] is int
          ? json['bloodPressureSystolic']
          : int.tryParse(json['bloodPressureSystolic']?.toString() ?? ''),
      bloodPressureDiastolic: json['bloodPressureDiastolic'] is int
          ? json['bloodPressureDiastolic']
          : int.tryParse(json['bloodPressureDiastolic']?.toString() ?? ''),
      sugarLevel: json['sugarLevel'] != null
          ? double.tryParse(json['sugarLevel'].toString())
          : null,
      temperature: json['temperature'] != null
          ? double.tryParse(json['temperature'].toString())
          : null,
      pulse: json['pulse'] is int
          ? json['pulse']
          : int.tryParse(json['pulse']?.toString() ?? ''),
      spo2: json['spo2'] is int
          ? json['spo2']
          : int.tryParse(json['spo2']?.toString() ?? ''),
    );
  }
}

class ConsultationTemplateService {
  static const String _customTemplatesKey = 'spmc_custom_consultation_templates';

  // ─── CURATED HOSPITAL SPECIALTY TEMPLATES ──────────────────────────────────
  static final List<ConsultationTemplate> curatedTemplates = [
    const ConsultationTemplate(
      id: 'gen_med_fever',
      title: 'Acute Viral Pyrexia / Febrile Illness',
      specialty: 'General Medicine',
      complaint:
          'High grade intermittent fever with chills and rigors x 3 days, accompanied by generalized myalgia, frontal headache, and fatigue.',
      examination:
          'General: Alert, febrile (101.2°F), hydrated. Pulse: 96 bpm, regular. BP: 120/80 mmHg. Pharynx mildly congested. Chest: Clear bilaterally, no crepitations. Abdomen: Soft, non-tender, no hepatosplenomegaly.',
      diagnosis: 'Acute febrile illness, unspecified [R50.9] - Viral Pyrexia',
      icd10Code: 'R50.9',
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      temperature: 101.2,
      pulse: 96,
      investigations: [
        'Complete Blood Count (CBC)',
        'Dengue NS1 Antigen & IgM',
        'Widal Test',
        'Urine Routine Examination',
      ],
      medications: [
        {
          'name': 'Tab Paracetamol 650mg',
          'dosage': '650mg',
          'frequency': '1-0-1-1',
          'duration': '3 days',
        },
        {
          'name': 'Tab Pantoprazole 40mg',
          'dosage': '40mg',
          'frequency': '1-0-0',
          'duration': '5 days',
        },
        {
          'name': 'ORS Powder (Electral)',
          'dosage': '1 sachet in 1L water',
          'frequency': 'TDS',
          'duration': '3 days',
        },
      ],
      clinicalNotes:
          'Adequate oral hydration (>2.5L fluids/day). Tepid sponging for temp > 101°F. Warning signs explained: persistent vomiting, bleeding tendencies, altered sensorium. Review in 48 hours with investigation reports.',
      treatmentPlan: 'Symptomatic & supportive management with close monitoring of platelet counts.',
    ),

    const ConsultationTemplate(
      id: 'cardio_htn',
      title: 'Essential Hypertension Review & Optimization',
      specialty: 'Cardiology',
      complaint:
          'Routine follow-up evaluation for blood pressure control. Patient reports occasional morning occipital heaviness. No chest pain, palpitations, orthopnea, or pedal edema.',
      examination:
          'General: Comfortable at rest. Pulse: 76 bpm, regular. Sitting BP: 152/94 mmHg (Right Arm), 150/92 mmHg (Left Arm). JVP not elevated. S1 S2 heard, no murmurs. Bilateral peripheral pulses well palpable. No pedal edema.',
      diagnosis: 'Essential (primary) hypertension [I10] - Uncontrolled Stage 1',
      icd10Code: 'I10',
      bloodPressureSystolic: 152,
      bloodPressureDiastolic: 94,
      temperature: 98.6,
      pulse: 76,
      investigations: [
        '12-Lead Electrocardiogram (ECG)',
        'Serum Creatinine & Electrolytes',
        'Lipid Profile (Fasting)',
        'Urine Routine & Microalbuminuria',
      ],
      medications: [
        {
          'name': 'Tab Telmisartan 40mg',
          'dosage': '40mg',
          'frequency': '1-0-0',
          'duration': '30 days',
        },
        {
          'name': 'Tab Amlodipine 5mg',
          'dosage': '5mg',
          'frequency': '0-0-1',
          'duration': '30 days',
        },
      ],
      clinicalNotes:
          'Advised strict DASH diet with low sodium intake (< 5g salt/day). 30-45 minutes brisk walking at least 5 days/week. Maintain a home BP chart morning and evening. Avoid NSAIDs without consultation.',
      treatmentPlan: 'Dual antihypertensive therapy (ARB + CCB). Review in 4 weeks with home BP log.',
    ),

    const ConsultationTemplate(
      id: 'diab_t2dm',
      title: 'Type 2 Diabetes Mellitus Glycemic Follow-up',
      specialty: 'Diabetology',
      complaint:
          '3-month routine glycemic review. Reports occasional post-prandial lethargy. No polyuria, polydipsia, burning micturition, tingling in feet, or visual blurring.',
      examination:
          'General: Fair built, BMI 27.4 kg/m². Pulse: 80 bpm, BP: 130/84 mmHg. Monofilament 10g sensory test intact bilaterally. Bilateral dorsalis pedis & posterior tibial pulses palpable. Feet inspected: No calluses, ulcers, or fungal infections.',
      diagnosis: 'Type 2 diabetes mellitus without complications [E11.9]',
      icd10Code: 'E11.9',
      bloodPressureSystolic: 130,
      bloodPressureDiastolic: 84,
      temperature: 98.4,
      pulse: 80,
      sugarLevel: 154.0,
      investigations: [
        'Fasting Blood Sugar (FBS)',
        'Post Prandial Blood Sugar (PPBS)',
        'Glycated Hemoglobin (HbA1c)',
        'Lipid Profile',
        'Urine Albumin-to-Creatinine Ratio (UACR)',
      ],
      medications: [
        {
          'name': 'Tab Metformin 500mg (SR)',
          'dosage': '500mg',
          'frequency': '1-0-1',
          'duration': '30 days',
        },
        {
          'name': 'Tab Glimepiride 1mg',
          'dosage': '1mg',
          'frequency': '1-0-0',
          'duration': '30 days',
        },
      ],
      clinicalNotes:
          'Reiterated medical nutrition therapy (MNT): portion control, low glycemic index foods, avoidance of refined sugars. Hypoglycemia warning signs (sweating, tremors, hunger) explained along with the "Rule of 15". Daily foot hygiene counseling.',
      treatmentPlan: 'Glycemic control optimization. Annual screening for diabetic retinopathy and neuropathy.',
    ),

    const ConsultationTemplate(
      id: 'ortho_lbp',
      title: 'Mechanical Low Back Pain & Lumbar Spondylosis',
      specialty: 'Orthopedics',
      complaint:
          'Aching low back pain x 2 weeks, exacerbated by prolonged sitting, forward bending, and lifting weights. No radiation to lower limbs, no sensory parasthesias, bowel and bladder habits intact.',
      examination:
          'Spine Inspection: Normal lumbar lordosis. Palpation: Moderate paraspinal muscle spasm present over L4-L5 region. Forward flexion limited by pain. Straight Leg Raise (SLR) test: Negative bilaterally (85°). Motor power 5/5 in all lower limb groups. Deep tendon reflexes intact.',
      diagnosis: 'Low back pain [M54.5] - Acute Lumbago / Lumbar Spondylosis',
      icd10Code: 'M54.5',
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      temperature: 98.6,
      pulse: 74,
      investigations: [
        'Digital X-Ray Lumbosacral Spine (AP & Lateral views)',
      ],
      medications: [
        {
          'name': 'Tab Aceclofenac 100mg + Paracetamol 325mg',
          'dosage': '100mg/325mg',
          'frequency': '1-0-1',
          'duration': '5 days',
        },
        {
          'name': 'Tab Thiocolchicoside 4mg',
          'dosage': '4mg',
          'frequency': '1-0-1',
          'duration': '5 days',
        },
        {
          'name': 'Cap Rabeprazole 20mg',
          'dosage': '20mg',
          'frequency': '1-0-0',
          'duration': '5 days',
        },
      ],
      clinicalNotes:
          'Avoid forward bending, twisting, and lifting heavy objects. Ergonomic seating with lumbar cushion support. Local heat fermentation twice daily. Gentle isometric core exercises after acute pain subsides.',
      treatmentPlan: 'Short-course analgesia + muscle relaxant followed by outpatient physical therapy.',
    ),

    const ConsultationTemplate(
      id: 'peds_urti',
      title: 'Acute Upper Respiratory Tract Infection (Pediatric)',
      specialty: 'Pediatrics',
      complaint:
          'Child brought with complaints of clear nasal discharge, dry irritable cough, mild throat irritation, and low-grade fever x 2 days. Child is active, accepting oral feeds adequately.',
      examination:
          'Child conscious, playful, hydrated. Temp: 99.8°F, Respiratory Rate: 26/min (normal, no tachypnea or retractions). Throat: Mild erythematous posterior pharyngeal wall, tonsils normal. Chest: Bilateral breath sounds vesicular, clear, no wheeze or ronchi.',
      diagnosis: 'Acute upper respiratory infection, unspecified [J06.9]',
      icd10Code: 'J06.9',
      temperature: 99.8,
      pulse: 104,
      spo2: 99,
      investigations: [],
      medications: [
        {
          'name': 'Syp Paracetamol 250mg/5ml',
          'dosage': '5ml (as per weight)',
          'frequency': 'TDS (SOS for fever > 100°F)',
          'duration': '3 days',
        },
        {
          'name': 'Syp Levocetirizine 2.5mg/5ml',
          'dosage': '2.5ml',
          'frequency': '0-0-1',
          'duration': '5 days',
        },
        {
          'name': 'Saline Nasal Drops (Otrivin S)',
          'dosage': '2 drops each nostril',
          'frequency': 'TDS before feeds',
          'duration': '5 days',
        },
      ],
      clinicalNotes:
          'Steam inhalation with humidified air. Continue regular breast/oral feeding. Reassurance given regarding viral nature. Red flags explained: fast breathing, chest indrawing, persistent lethargy, refusal to feed.',
      treatmentPlan: 'Symptomatic viral URI protocol without unnecessary antibiotic exposure.',
    ),

    const ConsultationTemplate(
      id: 'gastro_gerd',
      title: 'Gastro-Esophageal Reflux Disease (GERD) & Dyspepsia',
      specialty: 'Gastroenterology',
      complaint:
          'Burning retrosternal discomfort (heartburn) radiating upwards, sour water brash, bloating, and postprandial fullness x 3 weeks. Symptoms worsen on lying down immediately after heavy spicy meals.',
      examination:
          'General: Well-nourished. Abdomen: Soft, mild epigastric tenderness on deep palpation, no guarding, no organomegaly, normal bowel sounds. Cardiorespiratory examination unremarkable.',
      diagnosis: 'Gastro-esophageal reflux disease without esophagitis [K21.9]',
      icd10Code: 'K21.9',
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      temperature: 98.4,
      pulse: 72,
      investigations: [
        'Complete Blood Count (CBC)',
        'Ultrasound Whole Abdomen (to rule out cholelithiasis)',
      ],
      medications: [
        {
          'name': 'Tab Pantoprazole 40mg + Domperidone 30mg (SR)',
          'dosage': '40mg/30mg',
          'frequency': '1-0-0 (30 mins before breakfast)',
          'duration': '14 days',
        },
        {
          'name': 'Syp Sucralfate 1000mg/5ml',
          'dosage': '10ml',
          'frequency': 'TDS (2 hours after meals)',
          'duration': '7 days',
        },
      ],
      clinicalNotes:
          'Eat small, frequent meals. Strictly avoid coffee, aerated sodas, oily/spicy foods, and midnight snacks. Keep head end of bed elevated 6-8 inches. Avoid sleeping within 2-3 hours of dinner.',
      treatmentPlan: 'Proton-pump inhibitor + prokinetic course. Upper GI Endoscopy if alarm symptoms develop.',
    ),

    const ConsultationTemplate(
      id: 'derm_urticaria',
      title: 'Acute Allergic Urticaria & Dermatitis',
      specialty: 'Dermatology',
      complaint:
          'Sudden onset of intensely pruritic, erythematous raised skin lesions (wheals) appearing across limbs and torso x 24 hours. No facial swelling, lip edema, or breathing difficulty.',
      examination:
          'Dermatological: Multiple transient, edematous erythematous plaques with central clearing scattered over trunk and upper extremities. Dermographism positive. Mucous membranes normal, tongue & lips not swollen, no stridor.',
      diagnosis: 'Urticaria, unspecified [L50.9] - Acute Allergic Wheals',
      icd10Code: 'L50.9',
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      temperature: 98.6,
      pulse: 76,
      investigations: [
        'Complete Blood Count & Absolute Eosinophil Count (AEC)',
      ],
      medications: [
        {
          'name': 'Tab Bilastine 20mg',
          'dosage': '20mg',
          'frequency': '1-0-0 (on empty stomach)',
          'duration': '10 days',
        },
        {
          'name': 'Calamine Lotion',
          'dosage': 'Apply topically',
          'frequency': 'BD/TDS over itchy lesions',
          'duration': '7 days',
        },
      ],
      clinicalNotes:
          'Strictly avoid suspected trigger foods (seafood, nuts, artificial food dyes) or newly started medications. Cool compresses for itch relief. Avoid hot showers and tight clothing. Return immediately if lip swelling or wheezing occurs.',
      treatmentPlan: 'Non-sedating second generation antihistaminic regimen with topical soothing agents.',
    ),

    const ConsultationTemplate(
      id: 'pulmo_asthma',
      title: 'Bronchial Asthma — Mild Exacerbation',
      specialty: 'Pulmonology',
      complaint:
          'Known asthmatic presenting with nocturnal cough, chest tightness, and breathlessness x 3 days triggered by cold weather and dust exposure.',
      examination:
          'Alert, speaking in full sentences. SPO2: 96% on room air. Resp Rate: 22/min. Chest: Bilateral prolonged expiration with generalized polyphonic wheezing heard on auscultation. No cyanosis or accessory muscle usage.',
      diagnosis: 'Unspecified asthma, uncomplicated [J45.909]',
      icd10Code: 'J45.909',
      bloodPressureSystolic: 124,
      bloodPressureDiastolic: 82,
      temperature: 98.6,
      pulse: 88,
      spo2: 96,
      investigations: [
        'Peak Expiratory Flow Rate (PEFR)',
        'Chest X-Ray (PA view)',
        'Complete Blood Count (AEC)',
      ],
      medications: [
        {
          'name': 'Inhaler Budesonide 200mcg + Formoterol 6mcg (Budecort)',
          'dosage': '200/6 mcg',
          'frequency': '2 puffs BD with Spacer',
          'duration': '30 days',
        },
        {
          'name': 'Inhaler Levosalbutamol 50mcg (Levolin)',
          'dosage': '50mcg',
          'frequency': '2 puffs SOS for acute breathlessness',
          'duration': '30 days',
        },
        {
          'name': 'Tab Montelukast 10mg',
          'dosage': '10mg',
          'frequency': '0-0-1',
          'duration': '30 days',
        },
      ],
      clinicalNotes:
          'Demonstrated correct MDI inhaler and spacer technique with post-inhalation mouth gargling to prevent oral candidiasis. Avoid known aeroallergens, cold beverages, and passive tobacco smoke exposure.',
      treatmentPlan: 'ICS-LABA maintenance therapy with SABA reliever and leukotriene receptor antagonist.',
    ),

    const ConsultationTemplate(
      id: 'uro_uti',
      title: 'Acute Uncomplicated Urinary Tract Infection',
      specialty: 'Nephrology & Urology',
      complaint:
          'Burning micturition (dysuria), increased urinary frequency, and lower suprapubic discomfort x 4 days. Denies high fever with chills or flank pain.',
      examination:
          'General: Afebrile, vitals stable. Abdomen: Soft, mild suprapubic tenderness present on palpation. Renal angles non-tender bilaterally. External genitalia inspection normal.',
      diagnosis: 'Urinary tract infection, site not specified [N39.0] - Acute Cystitis',
      icd10Code: 'N39.0',
      bloodPressureSystolic: 120,
      bloodPressureDiastolic: 80,
      temperature: 99.0,
      pulse: 76,
      investigations: [
        'Urine Routine & Microscopy (Pus cells / Albumin)',
        'Urine Culture and Sensitivity (Clean-catch midstream)',
        'Ultrasound KUB (Kidney, Ureter, Bladder)',
      ],
      medications: [
        {
          'name': 'Tab Nitrofurantoin 100mg (SR)',
          'dosage': '100mg',
          'frequency': '1-0-1 (with meals)',
          'duration': '5 days',
        },
        {
          'name': 'Syp Disodium Hydrogen Citrate (Cital)',
          'dosage': '10ml in 1 glass water',
          'frequency': 'TDS',
          'duration': '5 days',
        },
        {
          'name': 'Tab Paracetamol 650mg',
          'dosage': '650mg',
          'frequency': '1-0-1 (SOS for pain)',
          'duration': '3 days',
        },
      ],
      clinicalNotes:
          'Drink abundant water (> 3 liters/day) to promote urinary flush. Complete full 5-day antibiotic course even if symptoms resolve earlier. Practice proper perineal hygiene. Review with culture report in 3 days.',
      treatmentPlan: 'Empirical urinary antiseptic course tailored upon urine culture & sensitivity.',
    ),
  ];

  // ─── CUSTOM DOCTOR TEMPLATES (PERSISTED LOCALLY) ──────────────────────────
  static Future<List<ConsultationTemplate>> getCustomTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getStringList(_customTemplatesKey) ?? [];
      return listStr
          .map((s) => ConsultationTemplate.fromJson(jsonDecode(s)))
          .toList();
    } catch (e) {
      debugPrint('Error loading custom templates: $e');
      return [];
    }
  }

  static Future<bool> saveCustomTemplate(ConsultationTemplate template) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getCustomTemplates();
      // Remove duplicate if same ID
      currentList.removeWhere((t) => t.id == template.id);
      currentList.insert(0, template);

      final encoded = currentList.map((t) => jsonEncode(t.toJson())).toList();
      return await prefs.setStringList(_customTemplatesKey, encoded);
    } catch (e) {
      debugPrint('Error saving custom template: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomTemplate(String templateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getCustomTemplates();
      currentList.removeWhere((t) => t.id == templateId);

      final encoded = currentList.map((t) => jsonEncode(t.toJson())).toList();
      return await prefs.setStringList(_customTemplatesKey, encoded);
    } catch (e) {
      debugPrint('Error deleting custom template: $e');
      return false;
    }
  }

  static Future<List<ConsultationTemplate>> getAllTemplates() async {
    final custom = await getCustomTemplates();
    return [...custom, ...curatedTemplates];
  }
}
