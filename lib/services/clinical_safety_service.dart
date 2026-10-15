import 'package:flutter/material.dart';

/// Represents a clinical drug-drug interaction alert
class DrugInteractionAlert {
  final String drug1;
  final String drug2;
  final String severity; // 'Major', 'Moderate', 'Minor'
  final String title;
  final String mechanism;
  final String clinicalAdvice;

  const DrugInteractionAlert({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.title,
    required this.mechanism,
    required this.clinicalAdvice,
  });

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'major':
      case 'contraindicated':
        return const Color(0xFFE53E3E); // Danger Red
      case 'moderate':
        return const Color(0xFFD97706); // Amber
      case 'minor':
      default:
        return const Color(0xFF2563EB); // Blue
    }
  }

  Color get severityBgColor {
    switch (severity.toLowerCase()) {
      case 'major':
      case 'contraindicated':
        return const Color(0xFFFEE2E2);
      case 'moderate':
        return const Color(0xFFFEF3C7);
      case 'minor':
      default:
        return const Color(0xFFDBEAFE);
    }
  }
}

/// Represents a patient drug allergy alert
class AllergyAlert {
  final String drugName;
  final String matchedAllergen;
  final String allergenCategory;
  final String severity; // 'Severe', 'Moderate'
  final String warningMessage;
  final bool isCrossReactivity;

  const AllergyAlert({
    required this.drugName,
    required this.matchedAllergen,
    required this.allergenCategory,
    required this.severity,
    required this.warningMessage,
    this.isCrossReactivity = false,
  });
}

class ClinicalSafetyService {
  // ─── DRUG-DRUG INTERACTIONS DATABASE ──────────────────────────────────────
  static final List<DrugInteractionAlert> _interactionRules = [
    // 1. Anticoagulants + Antiplatelets / NSAIDs
    DrugInteractionAlert(
      drug1: 'Aspirin',
      drug2: 'Warfarin',
      severity: 'Major',
      title: 'Severe Bleeding & Hemorrhage Risk',
      mechanism:
          'Synergistic inhibition of coagulation pathway and platelet aggregation significantly elevates gastrointestinal and intracranial bleeding risk.',
      clinicalAdvice:
          'Avoid concurrent use unless strictly indicated under specialist supervision. Monitor INR frequently and consider gastric mucosal protection (PPI).',
    ),
    DrugInteractionAlert(
      drug1: 'Warfarin',
      drug2: 'Ibuprofen',
      severity: 'Major',
      title: 'Increased Risk of Severe GI Bleeding',
      mechanism:
          'NSAIDs inhibit platelet function and induce gastric mucosal erosions while Warfarin inhibits vitamin K-dependent clotting factors.',
      clinicalAdvice:
          'Avoid concurrent use. Use Paracetamol for analgesia in patients on Warfarin.',
    ),
    DrugInteractionAlert(
      drug1: 'Warfarin',
      drug2: 'Diclofenac',
      severity: 'Major',
      title: 'High Bleeding Risk with NSAID',
      mechanism:
          'Diclofenac displaces Warfarin from plasma protein binding and inhibits platelet thromboxane A2.',
      clinicalAdvice:
          'Avoid combination. Substitute with Paracetamol or topical analgesics.',
    ),
    DrugInteractionAlert(
      drug1: 'Warfarin',
      drug2: 'Fluconazole',
      severity: 'Major',
      title: 'Elevated Warfarin Toxicity & INR Spikes',
      mechanism:
          'Fluconazole potent CYP2C9 inhibition decreases S-warfarin metabolism, sharply increasing prothrombin time/INR.',
      clinicalAdvice:
          'Reduce Warfarin dose by 50% and check INR daily, or select an alternative antifungal.',
    ),
    DrugInteractionAlert(
      drug1: 'Clopidogrel',
      drug2: 'Omeprazole',
      severity: 'Major',
      title: 'Reduced Antiplatelet Efficacy',
      mechanism:
          'Omeprazole inhibits CYP2C19, the primary enzyme converting Clopidogrel to its active antiplatelet metabolite, increasing thrombotic risk.',
      clinicalAdvice:
          'Switch to Pantoprazole or Rabeprazole, which exhibit significantly less CYP2C19 inhibition.',
    ),

    // 2. Cardiovascular & Renin-Angiotensin System
    DrugInteractionAlert(
      drug1: 'Telmisartan',
      drug2: 'Spironolactone',
      severity: 'Major',
      title: 'Life-Threatening Hyperkalemia Risk',
      mechanism:
          'Combined aldosterone blockade and angiotensin II inhibition impairs renal potassium excretion, risking cardiac arrhythmias.',
      clinicalAdvice:
          'Monitor serum potassium and renal parameters within 1 week of initiation. Discontinue potassium supplements.',
    ),
    DrugInteractionAlert(
      drug1: 'Ramipril',
      drug2: 'Spironolactone',
      severity: 'Major',
      title: 'Severe Hyperkalemia Risk',
      mechanism:
          'Dual renin-angiotensin-aldosterone blockade severely limits distal nephron potassium secretion.',
      clinicalAdvice:
          'Check baseline serum potassium. Avoid if baseline potassium > 5.0 mEq/L.',
    ),
    DrugInteractionAlert(
      drug1: 'Enalapril',
      drug2: 'Spironolactone',
      severity: 'Major',
      title: 'Severe Hyperkalemia Risk',
      mechanism:
          'Concurrent ACE inhibitor and potassium-sparing diuretic therapy creates cumulative potassium retention.',
      clinicalAdvice:
          'Monitor serum electrolytes closely. Advise patient against high-potassium salt substitutes.',
    ),
    DrugInteractionAlert(
      drug1: 'Sildenafil',
      drug2: 'Nitroglycerin',
      severity: 'Contraindicated',
      title: 'Fatal Hypotension & Cardiovascular Collapse',
      mechanism:
          'PDE5 inhibition potentiates nitric oxide-mediated cGMP accumulation, causing profound systemic vasodilation and circulatory collapse.',
      clinicalAdvice:
          'Absolute Contraindication! Nitrates must not be administered within 24-48 hours of PDE5 inhibitors.',
    ),
    DrugInteractionAlert(
      drug1: 'Amlodipine',
      drug2: 'Simvastatin',
      severity: 'Moderate',
      title: 'Increased Statin Concentration & Myopathy',
      mechanism:
          'Amlodipine inhibits CYP3A4-mediated clearance of Simvastatin, increasing systemic exposure and risk of rhabdomyolysis.',
      clinicalAdvice:
          'Limit Simvastatin daily dose to maximum 20 mg when co-prescribed with Amlodipine, or switch to Rosuvastatin.',
    ),
    DrugInteractionAlert(
      drug1: 'Digoxin',
      drug2: 'Amiodarone',
      severity: 'Major',
      title: 'Digoxin Toxicity (Bradycardia / Arrhythmia)',
      mechanism:
          'Amiodarone inhibits P-glycoprotein-mediated renal excretion of Digoxin, doubling serum Digoxin concentrations.',
      clinicalAdvice:
          'Reduce Digoxin dose by 50% upon starting Amiodarone. Monitor ECG and serum Digoxin levels.',
    ),

    // 3. NSAID & Renal / GI Interactions
    DrugInteractionAlert(
      drug1: 'Diclofenac',
      drug2: 'Telmisartan',
      severity: 'Moderate',
      title: 'Acute Kidney Injury (AKI) & Reduced BP Control',
      mechanism:
          'NSAIDs inhibit renal prostaglandins causing afferent arteriolar constriction while ARBs cause efferent vasodilation, dropping GFR.',
      clinicalAdvice:
          'Maintain adequate hydration. Monitor serum creatinine and blood pressure.',
    ),
    DrugInteractionAlert(
      drug1: 'Ibuprofen',
      drug2: 'Ramipril',
      severity: 'Moderate',
      title: 'Nephrotoxicity & Blunted Antihypertensive Response',
      mechanism:
          'Prostaglandin inhibition impairs renal blood flow and blunts ACE inhibitor vasodilatory response.',
      clinicalAdvice:
          'Avoid prolonged NSAID courses in patients with hypertension or baseline CKD.',
    ),
    DrugInteractionAlert(
      drug1: 'Methotrexate',
      drug2: 'Ibuprofen',
      severity: 'Major',
      title: 'Methotrexate Toxicity (Bone Marrow Suppression)',
      mechanism:
          'NSAIDs reduce renal perfusion and compete for organic anion transporters, elevating toxic methotrexate levels.',
      clinicalAdvice:
          'Avoid combination, especially with antineoplastic doses. Monitor complete blood counts closely.',
    ),

    // 4. Antibiotics & Anti-infectives
    DrugInteractionAlert(
      drug1: 'Ciprofloxacin',
      drug2: 'Theophylline',
      severity: 'Major',
      title: 'Theophylline Toxicity (Seizures & Tachycardia)',
      mechanism:
          'Ciprofloxacin inhibits CYP1A2, reducing theophylline clearance by up to 50%.',
      clinicalAdvice:
          'Reduce theophylline dose by one-third to one-half. Monitor serum theophylline levels.',
    ),
    DrugInteractionAlert(
      drug1: 'Azithromycin',
      drug2: 'Amiodarone',
      severity: 'Major',
      title: 'QT Interval Prolongation & Torsades de Pointes',
      mechanism:
          'Additive cardiac repolarization delay substantially elevates risk of polymorphic ventricular arrhythmias.',
      clinicalAdvice:
          'Obtain baseline ECG. Correct hypokalemia and hypomagnesemia. Consider alternative non-macrolide antibiotic.',
    ),
    DrugInteractionAlert(
      drug1: 'Atorvastatin',
      drug2: 'Clarithromycin',
      severity: 'Major',
      title: 'Severe Rhabdomyolysis Risk',
      mechanism:
          'Clarithromycin strongly inhibits CYP3A4, causing massive accumulation of Atorvastatin.',
      clinicalAdvice:
          'Temporarily suspend Atorvastatin during short-course Clarithromycin therapy, or substitute with Azithromycin.',
    ),

    // 5. CNS & Metabolic
    DrugInteractionAlert(
      drug1: 'Tramadol',
      drug2: 'Fluoxetine',
      severity: 'Major',
      title: 'Serotonin Syndrome & Seizure Risk',
      mechanism:
          'Combined serotonergic stimulation and CYP2D6 inhibition can precipitate central serotonin toxicity and lower seizure threshold.',
      clinicalAdvice:
          'Watch for mental status changes, autonomic hyperactivity, and neuromuscular hyperreflexia.',
    ),
    DrugInteractionAlert(
      drug1: 'Metformin',
      drug2: 'Alcohol',
      severity: 'Major',
      title: 'Increased Risk of Lactic Acidosis',
      mechanism:
          'Ethanol potentiates Metformin effect on lactate metabolism and impairs hepatic gluconeogenesis.',
      clinicalAdvice:
          'Caution patient against excessive alcohol consumption while taking Metformin.',
    ),
    DrugInteractionAlert(
      drug1: 'Levothyroxine',
      drug2: 'Calcium',
      severity: 'Moderate',
      title: 'Decreased Thyroid Hormone Absorption',
      mechanism:
          'Calcium salts form an insoluble chelate with Levothyroxine in the gastrointestinal tract.',
      clinicalAdvice:
          'Separate administration times by at least 4 hours (take Levothyroxine in morning on empty stomach).',
    ),
  ];

  // ─── ALLERGEN FAMILIES & DRUG MATCHING ────────────────────────────────────
  static final Map<String, List<String>> _allergenFamilies = {
    'penicillin': [
      'penicillin',
      'amoxicillin',
      'ampicillin',
      'augmentin',
      'piperacillin',
      'cloxacillin',
      'amox',
      'penam',
    ],
    'cephalosporin': [
      'cephalexin',
      'cefixime',
      'cefuroxime',
      'ceftriaxone',
      'cefotaxime',
      'cefepime',
      'cefdinir',
      'cefpodoxime',
      'cef',
    ],
    'nsaid': [
      'aspirin',
      'ibuprofen',
      'diclofenac',
      'aceclofenac',
      'naproxen',
      'ketorolac',
      'piroxicam',
      'mefenamic',
      'meloxicam',
      'indomethacin',
      'celecoxib',
      'etoricoxib',
      'combiflam',
      'voveran',
    ],
    'sulfa': [
      'sulfa',
      'sulfonamide',
      'cotrimoxazole',
      'trimethoprim',
      'bactrim',
      'septran',
      'sulfasalazine',
      'dapsone',
    ],
    'fluoroquinolone': [
      'ciprofloxacin',
      'levofloxacin',
      'ofloxacin',
      'moxifloxacin',
      'norfloxacin',
      'cipro',
      'levo',
    ],
    'macrolide': [
      'azithromycin',
      'clarithromycin',
      'erythromycin',
      'roxithromycin',
    ],
    'paracetamol': [
      'paracetamol',
      'acetaminophen',
      'crocin',
      'calpol',
      'dolo',
    ],
    'statin': [
      'atorvastatin',
      'simvastatin',
      'rosuvastatin',
      'pravastatin',
    ],
    'opioid': [
      'tramadol',
      'codeine',
      'morphine',
      'fentanyl',
      'pethidine',
    ],
  };

  /// Cross-reactivity mapping (e.g. Penicillin allergy cross-reacts with Cephalosporins ~3-5%)
  static final Map<String, List<String>> _crossReactivity = {
    'penicillin': ['cephalosporin'],
    'cephalosporin': ['penicillin'],
    'aspirin': ['nsaid'],
    'nsaid': ['aspirin'],
  };

  /// Normalizes drug names for substring/token matching
  static String _cleanName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\b(tab|cap|syp|inj|ointment|gel|cream|mg|ml|gm)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  /// Checks prescribed medications against patient allergy notes
  static List<AllergyAlert> checkAllergies({
    required String? patientAllergyText,
    required List<String> prescribedMedications,
  }) {
    final List<AllergyAlert> alerts = [];
    if (patientAllergyText == null || patientAllergyText.trim().isEmpty) {
      return alerts;
    }

    final allergyTextClean = patientAllergyText.toLowerCase();

    // Identify which allergen families match patient's recorded allergies
    final detectedFamilies = <String>{};
    for (var entry in _allergenFamilies.entries) {
      final familyKey = entry.key;
      final keywords = entry.value;

      if (allergyTextClean.contains(familyKey)) {
        detectedFamilies.add(familyKey);
      } else {
        for (var kw in keywords) {
          if (allergyTextClean.contains(kw)) {
            detectedFamilies.add(familyKey);
            break;
          }
        }
      }
    }

    // Now test each prescribed medication
    for (var rawMed in prescribedMedications) {
      final cleanMed = _cleanName(rawMed);
      if (cleanMed.isEmpty) continue;

      // 1. Direct match with detected allergen family
      for (var family in detectedFamilies) {
        final familyDrugs = _allergenFamilies[family] ?? [];
        final isMatch = familyDrugs.any((drug) => cleanMed.contains(drug) || drug.contains(cleanMed));

        if (isMatch) {
          alerts.add(
            AllergyAlert(
              drugName: rawMed,
              matchedAllergen: family.toUpperCase(),
              allergenCategory: family.toUpperCase(),
              severity: 'Severe',
              warningMessage:
                  'Patient has documented allergy to "${family.toUpperCase()}". Prescribing "$rawMed" is strongly contraindicated due to high risk of severe anaphylaxis/hypersensitivity!',
            ),
          );
        } else {
          // 2. Check cross-reactivity
          final crossFamilies = _crossReactivity[family] ?? [];
          for (var xFam in crossFamilies) {
            final xDrugs = _allergenFamilies[xFam] ?? [];
            if (xDrugs.any((d) => cleanMed.contains(d) || d.contains(cleanMed))) {
              alerts.add(
                AllergyAlert(
                  drugName: rawMed,
                  matchedAllergen: family.toUpperCase(),
                  allergenCategory: xFam.toUpperCase(),
                  severity: 'Moderate',
                  isCrossReactivity: true,
                  warningMessage:
                      'Potential Cross-Reactivity: Patient is allergic to "${family.toUpperCase()}". "$rawMed" ($xFam family) has a documented cross-reactivity risk. Prescribe with caution.',
                ),
              );
            }
          }
        }
      }
    }

    return alerts;
  }

  /// Checks for drug-drug interactions among prescribed medications
  static List<DrugInteractionAlert> checkDrugInteractions(
    List<String> prescribedMedications,
  ) {
    final List<DrugInteractionAlert> detectedInteractions = [];
    if (prescribedMedications.length < 2) return detectedInteractions;

    final cleanedList = prescribedMedications.map((m) => _cleanName(m)).toList();

    for (var rule in _interactionRules) {
      final d1Clean = _cleanName(rule.drug1);
      final d2Clean = _cleanName(rule.drug2);

      int idx1 = -1;
      int idx2 = -1;

      for (int i = 0; i < cleanedList.length; i++) {
        if (cleanedList[i].contains(d1Clean) || d1Clean.contains(cleanedList[i])) {
          idx1 = i;
        }
        if (cleanedList[i].contains(d2Clean) || d2Clean.contains(cleanedList[i])) {
          idx2 = i;
        }
      }

      if (idx1 != -1 && idx2 != -1 && idx1 != idx2) {
        // Match found!
        detectedInteractions.add(rule);
      }
    }

    return detectedInteractions;
  }
}
