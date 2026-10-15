class Icd10Item {
  final String code;
  final String description;
  final String category;

  const Icd10Item({
    required this.code,
    required this.description,
    required this.category,
  });

  String get formatted => '[$code] $description';

  @override
  String toString() => formatted;
}

class Icd10Database {
  static const List<Icd10Item> items = [
    // Cardiovascular System
    Icd10Item(code: 'I10', description: 'Essential (primary) hypertension', category: 'Circulatory System'),
    Icd10Item(code: 'I11.9', description: 'Hypertensive heart disease without heart failure', category: 'Circulatory System'),
    Icd10Item(code: 'I20.9', description: 'Angina pectoris, unspecified', category: 'Circulatory System'),
    Icd10Item(code: 'I21.9', description: 'Acute myocardial infarction, unspecified', category: 'Circulatory System'),
    Icd10Item(code: 'I25.10', description: 'Atherosclerotic heart disease of native coronary artery', category: 'Circulatory System'),
    Icd10Item(code: 'I48.91', description: 'Unspecified atrial fibrillation', category: 'Circulatory System'),
    Icd10Item(code: 'I50.9', description: 'Heart failure, unspecified', category: 'Circulatory System'),
    Icd10Item(code: 'I47.1', description: 'Supraventricular tachycardia', category: 'Circulatory System'),
    Icd10Item(code: 'I95.9', description: 'Hypotension, unspecified', category: 'Circulatory System'),

    // Endocrine, Nutritional and Metabolic Diseases
    Icd10Item(code: 'E11.9', description: 'Type 2 diabetes mellitus without complications', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E11.65', description: 'Type 2 diabetes mellitus with hyperglycemia', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E11.21', description: 'Type 2 diabetes mellitus with diabetic nephropathy', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E11.319', description: 'Type 2 diabetes mellitus with unspecified diabetic retinopathy', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E10.9', description: 'Type 1 diabetes mellitus without complications', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E03.9', description: 'Hypothyroidism, unspecified', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E05.90', description: 'Thyrotoxicosis without thyrotoxic crisis or storm', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E78.5', description: 'Hyperlipidemia, unspecified', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E78.0', description: 'Pure hypercholesterolemia', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E66.9', description: 'Obesity, unspecified', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E86.0', description: 'Dehydration', category: 'Endocrine & Metabolic'),
    Icd10Item(code: 'E79.0', description: 'Hyperuricemia without signs of inflammatory arthritis and tophaceous disease', category: 'Endocrine & Metabolic'),

    // Respiratory System
    Icd10Item(code: 'J00', description: 'Acute nasopharyngitis (common cold)', category: 'Respiratory System'),
    Icd10Item(code: 'J01.90', description: 'Acute sinusitis, unspecified', category: 'Respiratory System'),
    Icd10Item(code: 'J02.9', description: 'Acute pharyngitis, unspecified', category: 'Respiratory System'),
    Icd10Item(code: 'J03.90', description: 'Acute tonsillitis, unspecified', category: 'Respiratory System'),
    Icd10Item(code: 'J06.9', description: 'Acute upper respiratory infection, unspecified', category: 'Respiratory System'),
    Icd10Item(code: 'J18.9', description: 'Pneumonia, unspecified organism', category: 'Respiratory System'),
    Icd10Item(code: 'J20.9', description: 'Acute bronchitis, unspecified', category: 'Respiratory System'),
    Icd10Item(code: 'J44.9', description: 'Chronic obstructive pulmonary disease, unspecified', category: 'Respiratory System'),
    Icd10Item(code: 'J45.909', description: 'Unspecified asthma, uncomplicated', category: 'Respiratory System'),
    Icd10Item(code: 'J30.9', description: 'Allergic rhinitis, unspecified', category: 'Respiratory System'),

    // Digestive System
    Icd10Item(code: 'K21.9', description: 'Gastro-esophageal reflux disease without esophagitis', category: 'Digestive System'),
    Icd10Item(code: 'K29.70', description: 'Gastritis, unspecified, without bleeding', category: 'Digestive System'),
    Icd10Item(code: 'K30', description: 'Functional dyspepsia', category: 'Digestive System'),
    Icd10Item(code: 'K58.9', description: 'Irritable bowel syndrome without diarrhea', category: 'Digestive System'),
    Icd10Item(code: 'K52.9', description: 'Noninfective gastroenteritis and colitis, unspecified', category: 'Digestive System'),
    Icd10Item(code: 'K59.00', description: 'Constipation, unspecified', category: 'Digestive System'),
    Icd10Item(code: 'K35.80', description: 'Unspecified acute appendicitis', category: 'Digestive System'),
    Icd10Item(code: 'K80.20', description: 'Calculus of gallbladder without cholecystitis', category: 'Digestive System'),
    Icd10Item(code: 'K76.0', description: 'Fatty (change of) liver, not elsewhere classified', category: 'Digestive System'),
    Icd10Item(code: 'K64.9', description: 'Hemorrhoids, unspecified', category: 'Digestive System'),

    // Infectious and Parasitic Diseases
    Icd10Item(code: 'A09', description: 'Infectious gastroenteritis and colitis, unspecified', category: 'Infectious Diseases'),
    Icd10Item(code: 'A01.0', description: 'Typhoid fever', category: 'Infectious Diseases'),
    Icd10Item(code: 'A90', description: 'Dengue fever', category: 'Infectious Diseases'),
    Icd10Item(code: 'B54', description: 'Unspecified malaria', category: 'Infectious Diseases'),
    Icd10Item(code: 'B34.9', description: 'Viral infection, unspecified', category: 'Infectious Diseases'),
    Icd10Item(code: 'B01.9', description: 'Varicella without complication (Chickenpox)', category: 'Infectious Diseases'),
    Icd10Item(code: 'B02.9', description: 'Zoster without complications (Shingles)', category: 'Infectious Diseases'),
    Icd10Item(code: 'A15.0', description: 'Tuberculosis of lung', category: 'Infectious Diseases'),

    // Musculoskeletal System and Connective Tissue
    Icd10Item(code: 'M54.5', description: 'Low back pain', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M54.2', description: 'Cervicalgia (Neck pain)', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M17.9', description: 'Osteoarthritis of knee, unspecified', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M19.90', description: 'Unspecified osteoarthritis, unspecified site', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M25.50', description: 'Pain in unspecified joint', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M79.1', description: 'Myalgia (Muscle pain)', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M10.9', description: 'Gout, unspecified', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M81.0', description: 'Age-related osteoporosis without current pathological fracture', category: 'Musculoskeletal System'),
    Icd10Item(code: 'M75.0', description: 'Adhesive capsulitis of shoulder (Frozen shoulder)', category: 'Musculoskeletal System'),

    // Nervous System & Mental Disorders
    Icd10Item(code: 'G43.909', description: 'Migraine, unspecified, not intractable, without status migrainosus', category: 'Nervous System'),
    Icd10Item(code: 'G44.209', description: 'Tension-type headache, unspecified', category: 'Nervous System'),
    Icd10Item(code: 'G40.909', description: 'Epilepsy, unspecified, not intractable', category: 'Nervous System'),
    Icd10Item(code: 'G47.00', description: 'Insomnia, unspecified', category: 'Nervous System'),
    Icd10Item(code: 'G45.9', description: 'Transient cerebral ischemic attack, unspecified', category: 'Nervous System'),
    Icd10Item(code: 'F32.9', description: 'Major depressive disorder, single episode, unspecified', category: 'Mental Health'),
    Icd10Item(code: 'F41.9', description: 'Anxiety disorder, unspecified', category: 'Mental Health'),
    Icd10Item(code: 'F41.1', description: 'Generalized anxiety disorder', category: 'Mental Health'),

    // Genitourinary System
    Icd10Item(code: 'N39.0', description: 'Urinary tract infection, site not specified', category: 'Genitourinary System'),
    Icd10Item(code: 'N20.1', description: 'Calculus of ureter (Ureteral stone)', category: 'Genitourinary System'),
    Icd10Item(code: 'N20.0', description: 'Calculus of kidney (Kidney stone)', category: 'Genitourinary System'),
    Icd10Item(code: 'N18.9', description: 'Chronic kidney disease, unspecified', category: 'Genitourinary System'),
    Icd10Item(code: 'N40.0', description: 'Benign prostatic hyperplasia without lower urinary tract symptoms', category: 'Genitourinary System'),
    Icd10Item(code: 'N94.6', description: 'Dysmenorrhea, unspecified', category: 'Genitourinary System'),

    // Skin and Subcutaneous Tissue
    Icd10Item(code: 'L20.9', description: 'Atopic dermatitis, unspecified', category: 'Skin & Subcutaneous'),
    Icd10Item(code: 'L30.9', description: 'Dermatitis, unspecified', category: 'Skin & Subcutaneous'),
    Icd10Item(code: 'L50.9', description: 'Urticaria, unspecified', category: 'Skin & Subcutaneous'),
    Icd10Item(code: 'L70.0', description: 'Acne vulgaris', category: 'Skin & Subcutaneous'),
    Icd10Item(code: 'L03.90', description: 'Cellulitis, unspecified', category: 'Skin & Subcutaneous'),
    Icd10Item(code: 'B35.9', description: 'Dermatophytosis, unspecified (Fungal skin infection)', category: 'Skin & Subcutaneous'),
    Icd10Item(code: 'L29.9', description: 'Pruritus, unspecified', category: 'Skin & Subcutaneous'),

    // Blood and Blood-forming Organs
    Icd10Item(code: 'D50.9', description: 'Iron deficiency anemia, unspecified', category: 'Hematology'),
    Icd10Item(code: 'D64.9', description: 'Anemia, unspecified', category: 'Hematology'),
    Icd10Item(code: 'D51.9', description: 'Vitamin B12 deficiency anemia, unspecified', category: 'Hematology'),

    // General Symptoms & Clinical Findings (R Codes)
    Icd10Item(code: 'R50.9', description: 'Fever, unspecified', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R05', description: 'Cough', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R07.9', description: 'Chest pain, unspecified', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R10.9', description: 'Abdominal pain, unspecified', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R11.2', description: 'Nausea with vomiting, unspecified', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R51', description: 'Headache', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R42', description: 'Dizziness and giddiness', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R53.83', description: 'Other fatigue', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R06.02', description: 'Shortness of breath', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R00.0', description: 'Tachycardia, unspecified', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R60.9', description: 'Edema, unspecified', category: 'Symptoms & Clinical Findings'),
    Icd10Item(code: 'R73.09', description: 'Other abnormal glucose (Impaired fasting glucose)', category: 'Symptoms & Clinical Findings'),

    // Injury & Trauma
    Icd10Item(code: 'S93.40', description: 'Sprain of unspecified ligament of ankle', category: 'Injury & Trauma'),
    Icd10Item(code: 'S00.93', description: 'Contusion of unspecified part of head', category: 'Injury & Trauma'),
    Icd10Item(code: 'T14.90', description: 'Injury, unspecified', category: 'Injury & Trauma'),
    Icd10Item(code: 'T78.40', description: 'Allergy, unspecified', category: 'Injury & Trauma'),
  ];

  static List<Icd10Item> search(String query, {int limit = 25}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items.take(limit).toList();

    // Exact code match or prefix match gets top priority
    final codeMatches = <Icd10Item>[];
    final descMatches = <Icd10Item>[];

    for (final item in items) {
      final codeLower = item.code.toLowerCase();
      final descLower = item.description.toLowerCase();

      if (codeLower == q || codeLower.startsWith(q)) {
        codeMatches.add(item);
      } else if (descLower.contains(q) || codeLower.contains(q)) {
        descMatches.add(item);
      }
    }

    return [...codeMatches, ...descMatches].take(limit).toList();
  }
}
