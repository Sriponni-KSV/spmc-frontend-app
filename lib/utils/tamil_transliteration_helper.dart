import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

/// Utility class for translating/transliterating Indian and English patient
/// and doctor names into natural Tamil script.
class TamilTransliterationHelper {
  /// Returns true if the string already contains Tamil unicode characters (0x0B80 - 0x0BFF).
  static bool hasTamil(String text) {
    return RegExp(r'[\u0B80-\u0BFF]').hasMatch(text);
  }

  // Common titles
  static final Map<String, String> _titles = {
    'dr': 'மரு.',
    'dr.': 'மரு.',
    'doctor': 'மருத்துவர்',
    'mr': 'திரு.',
    'mr.': 'திரு.',
    'mrs': 'திருமதி.',
    'mrs.': 'திருமதி.',
    'ms': 'செல்வி.',
    'ms.': 'செல்வி.',
    'master': 'மாஸ்டர்',
    'baby': 'குழந்தை',
  };

  // English initials to Tamil phonetic sounds
  static final Map<String, String> _initials = {
    'a': 'ஏ', 'b': 'பி', 'c': 'சி', 'd': 'டி', 'e': 'இ',
    'f': 'எப்', 'g': 'ஜி', 'h': 'ஹெச்', 'i': 'ஐ', 'j': 'ஜே',
    'k': 'கே', 'l': 'எல்', 'm': 'எம்', 'n': 'என்', 'o': 'ஓ',
    'p': 'பி', 'q': 'கியூ', 'r': 'ஆர்', 's': 'எஸ்', 't': 'டி',
    'u': 'யு', 'v': 'வி', 'w': 'டபிள்யூ', 'x': 'எக்ஸ்', 'y': 'ஒய்', 'z': 'இஸட்',
  };

  // High-accuracy curated dictionary for standard Tamil names
  static final Map<String, String> _dictionary = {
    'kumar': 'குமார்',
    'kumaran': 'குமரன்',
    'ramesh': 'ரமேஷ்',
    'suresh': 'சுரேஷ்',
    'murugan': 'முருகன்',
    'murugesan': 'முருகேசன்',
    'priya': 'பிரியா',
    'anitha': 'அனிதா',
    'kavitha': 'கவிதா',
    'rajesh': 'ராஜேஷ்',
    'vijay': 'விஜய்',
    'ajith': 'அஜித்',
    'selvan': 'செல்வன்',
    'selvam': 'செல்வம்',
    'sangeetha': 'சங்கீதா',
    'vignesh': 'விக்னேஷ்',
    'vigneshwaran': 'விக்னேஸ்வரன்',
    'lakshmi': 'லட்சுமி',
    'gopal': 'கோபால்',
    'deepa': 'தீபா',
    'deepak': 'தீபக்',
    'mohan': 'மோகன்',
    'karthik': 'கார்த்திக்',
    'karthikeyan': 'கார்த்திகேயன்',
    'saravanan': 'சரவணன்',
    'mani': 'மணி',
    'manikandan': 'மணிகண்டன்',
    'ravi': 'ரவி',
    'ravichandran': 'ரவிச்சந்திரன்',
    'senthil': 'செந்தில்',
    'senthilkumar': 'செந்தில்குமார்',
    'divya': 'திவ்யா',
    'pooja': 'பூஜா',
    'arun': 'அருண்',
    'arunkumar': 'அருண்குமார்',
    'bala': 'பாலா',
    'balaji': 'பாலாஜி',
    'balamurugan': 'பாலமுருகன்',
    'chitra': 'சித்ரா',
    'dinesh': 'தினேஷ்',
    'hari': 'ஹரி',
    'harish': 'ஹரிஷ்',
    'praveen': 'பிரவீன்',
    'sundar': 'சுந்தர்',
    'sundaram': 'சுந்தரம்',
    'anand': 'ஆனந்த்',
    'meena': 'மீனா',
    'meenakshi': 'மீனாட்சி',
    'shankar': 'சங்கர்',
    'swaminathan': 'சுவாமிநாதன்',
    'john': 'ஜான்',
    'gayu': 'காயு',
    'gayathri': 'காயத்ரி',
    'malini': 'மாலினி',
    'malathi': 'மாலதி',
    'rani': 'ராணி',
    'raja': 'ராஜா',
    'raj': 'ராஜ்',
    'mary': 'மேரி',
    'david': 'டேவிட்',
    'radha': 'ராதா',
    'krishnan': 'கிருஷ்ணன்',
    'krishna': 'கிருஷ்ணா',
    'venkat': 'வெங்கட்',
    'venkatesh': 'வெங்கடேஷ்',
    'ram': 'ராம்',
    'ganesh': 'கணேஷ்',
    'sathish': 'சதீஷ்',
    'preethi': 'ப்ரீத்தி',
    'revathi': 'ரேவதி',
    'vidya': 'வித்யா',
    'shanthi': 'சாந்தி',
    'kalai': 'கலை',
    'kalaiselvan': 'கலைச்செல்வன்',
    'kalaiselvi': 'கலைச்செல்வி',
    'malar': 'மலர்',
    'malarvizhi': 'மலர்விழி',
    'nisha': 'நிஷா',
    'pavithra': 'பவித்ரா',
    'sandhya': 'சந்தியா',
    'sneha': 'சினேகா',
    'subha': 'சுபா',
    'swapna': 'ஸ்வப்னா',
    'vanitha': 'வனிதா',
    'vasanth': 'வசந்த்',
    'vasanthi': 'வசந்தி',
    'vinoth': 'வினோத்',
    'vinothkumar': 'வினோத்குமார்',
    'yuvaraj': 'யுவராஜ்',
    'raghavan': 'ராகவன்',
    'raghu': 'ரகு',
    'madhavan': 'மாதவன்',
    'muthu': 'முத்து',
    'perumal': 'பெருமாள்',
    'kannan': 'கண்ணன்',
    'elango': 'இளங்கோ',
    'velu': 'வேலு',
    'velmurugan': 'வேல்முருகன்',
    'thangam': 'தங்கம்',
    'sivakumar': 'சிவகுமார்',
    'siva': 'சிவா',
    'prabhu': 'பிரபு',
    'prakash': 'பிரகாஷ்',
    'ashok': 'அசோக்',
    'bharath': 'பரத்',
    'dharani': 'தரணி',
    'gowri': 'கௌரி',
    'janani': 'ஜனனி',
    'keerthana': 'கீர்த்தனா',
    'loganathan': 'லோகநாதன்',
    'nandhini': 'நந்தினி',
    'naveen': 'நவீன்',
    'pradeep': 'பிரதீப்',
    'ranjith': 'ரஞ்சித்',
    'saranya': 'சரண்யா',
    'sathya': 'சத்யா',
    'sowmya': 'சௌமியா',
    'subash': 'சுபாஷ்',
    'sumathi': 'சுமதி',
    'surya': 'சூர்யா',
    'thangavel': 'தங்கவேல்',
    'uday': 'உதய்',
    'uma': 'உமா',
    'usha': 'உஷா',
    'varun': 'வருண்',
    'vijayan': 'விஜயன்',
    'vimal': 'விமல்',
    'yamuna': 'யமுனா',
    'abinaya': 'அபிநயா',
    'aishwarya': 'ஐஸ்வர்யா',
    'akash': 'ஆகாஷ்',
    'akshaya': 'அக்ஷயா',
    'amutha': 'அமுதா',
    'banu': 'பானு',
    'bhuvanesh': 'புவனேஷ்',
    'boomika': 'பூமிகா',
    'bhoomika': 'பூமிகா',
    'bhumika': 'பூமிகா',
    'chellappa': 'செல்லப்பா',
    'devi': 'தேவி',
    'deva': 'தேவா',
    'devan': 'தேவன்',
    'devaraj': 'தேவராஜ்',
    'devika': 'தேவிகா',
    'dharshini': 'தர்ஷினி',
    'deepika': 'தீபிகா',
    'gomathi': 'கோமதி',
    'jeeva': 'ஜீவா',
    'kanchana': 'காஞ்சனா',
    'karthika': 'கார்த்திகா',
    'kousalya': 'கௌசல்யா',
    'lavanya': 'லாவண்யா',
    'madhumitha': 'மதுமிதா',
    'mahesh': 'மகேஷ்',
    'mallika': 'மல்லிகா',
    'manonmani': 'மனோன்மணி',
    'mohamed': 'முகமது',
    'muthukumar': 'முத்துக்குமார்',
    'mythili': 'மைத்திலி',
    'nivi': 'நிவி',
    'niva': 'நிவா',
    'nivetha': 'நிவேதா',
    'nivedha': 'நிவேதா',
    'niveditha': 'நிவேதிதா',
    'nithya': 'நித்யா',
    'padma': 'பத்மா',
    'parvathi': 'பார்வதி',
    'ponnusamy': 'பொன்னுசாமி',
    'poongodi': 'பூங்கொடி',
    'pushpa': 'புஷ்பா',
    'rajendran': 'ராஜேந்திரன்',
    'ramani': 'ரமணி',
    'sakthivel': 'சக்திவேல்',
    'sasikala': 'சசிகலா',
    'soundar': 'சௌந்தர்',
    'sudha': 'சுதா',
    'suganthi': 'சுகந்தி',
    'sugunan': 'சுகுணன்',
    'thangamani': 'தங்கமணி',
    'thirumalai': 'திருமலை',
    'vaishnavi': 'வைஷ்ணவி',
    'veena': 'வீணா',
    'venkatraman': 'வெங்கட்ராமன்',
    'vidhyalakshmi': 'வித்யாலட்சுமி',
    'vijayalakshmi': 'விஜயலட்சுமி',
    'vishnu': 'விஷ்ணு',
    'yasodha': 'யசோதா',
    'yuvasri': 'யுவஸ்ரீ',
    'patient': 'நோயாளி',
    'unknown': 'தெரியவில்லை',
    'unknown patient': 'அறியப்படாத நோயாளி',
  };

  // Rule-based phonetic transliteration for unlisted names
  static String _transliteratePhonetic(String word) {
    if (word.isEmpty) return '';
    final lower = word.toLowerCase();

    // Map for independent initial vowels
    final initVowels = {
      'aa': 'ஆ', 'a': 'அ', 'ee': 'ஈ', 'ii': 'ஈ', 'i': 'இ',
      'oo': 'ஊ', 'uu': 'ஊ', 'u': 'உ', 'ea': 'ஏ', 'ae': 'ஏ',
      'e': 'எ', 'ai': 'ஐ', 'oa': 'ஓ', 'o': 'ஒ', 'au': 'ஔ', 'ou': 'ஔ', 'ow': 'ஔ',
    };

    // Dependent vowel signs (உயிர்மெய்)
    final depVowels = {
      'aa': 'ா', 'a': '', 'ee': 'ீ', 'ii': 'ீ', 'i': 'ி',
      'oo': 'ூ', 'uu': 'ூ', 'u': 'ு', 'ea': 'ே', 'ae': 'ே',
      'e': 'ெ', 'ai': 'ை', 'oa': 'ோ', 'o': 'ொ', 'au': 'ௌ', 'ou': 'ௌ', 'ow': 'ௌ',
    };

    // Consonant clusters & consonants (sorted descending by length)
    final consonants = {
      'shri': 'ஸ்ரீ', 'sri': 'ஸ்ரீ', 'ksh': 'க்ஷ',
      'gnesh': 'க்னேஷ்', 'kkh': 'க்க', 'ggh': 'க்க', 'cch': 'ச்ச',
      'tth': 'த்த', 'pph': 'ப்ப', 'nth': 'ந்த', 'ndh': 'ந்த',
      'ng': 'ங', 'nj': 'ஞ', 'gn': 'ஞ', 'th': 'த', 'dh': 'த',
      'ch': 'ச', 'sh': 'ஷ', 'zh': 'ழ', 'rh': 'ற', 'ph': 'ப',
      'bh': 'ப', 'kh': 'க', 'gh': 'க', 'kr': 'க்ர', 'pr': 'ப்ர',
      'br': 'ப்ர', 'tr': 'த்ர', 'dr': 'த்ர', 'st': 'ஸ்த்', 'sp': 'ஸ்ப்',
      'sk': 'ஸ்க்', 'sm': 'ஸ்ம', 'sn': 'ஸ்ந', 'k': 'க', 'g': 'க',
      'c': 'க', 'j': 'ஜ', 's': 'ச', 't': 'ட', 'd': 'த',
      'n': 'ன', 'p': 'ப', 'b': 'ப', 'm': 'ம', 'y': 'ய',
      'r': 'ர', 'l': 'ல', 'v': 'வ', 'w': 'வ', 'h': 'ஹ', 'z': 'ஸ',
    };

    final buffer = StringBuffer();
    int i = 0;
    bool isStart = true;

    while (i < lower.length) {
      // Check if at start: special syllables for Indian names
      if (isStart) {
        // 'de' -> 'தே' (e.g. Devi -> தேவி, Devan, Deva)
        if (i + 2 <= lower.length && lower.substring(i, i + 2) == 'de') {
          buffer.write('தே');
          i += 2;
          isStart = false;
          continue;
        }

        // Initial independent vowels
        String? matchedInitVowel;
        int vowelLen = 0;
        for (var len = 2; len >= 1; len--) {
          if (i + len <= lower.length) {
            final sub = lower.substring(i, i + len);
            if (initVowels.containsKey(sub)) {
              matchedInitVowel = initVowels[sub];
              vowelLen = len;
              break;
            }
          }
        }
        if (matchedInitVowel != null) {
          buffer.write(matchedInitVowel);
          i += vowelLen;
          isStart = false;
          continue;
        }
      }

      // Match consonant
      String? matchedConsonant;
      int consLen = 0;
      for (var len = 5; len >= 1; len--) {
        if (i + len <= lower.length) {
          final sub = lower.substring(i, i + len);
          if (consonants.containsKey(sub)) {
            matchedConsonant = consonants[sub];
            consLen = len;
            break;
          }
        }
      }

      if (matchedConsonant != null) {
        // In Tamil, words never begin with 'ன' (two-loop na); at word start, 'n' is dental 'ந'
        if (isStart && lower.substring(i, i + consLen) == 'n') {
          matchedConsonant = 'ந';
        }
        // In Tamil names, initial 'd' is dental 'த' (e.g. Devi, Dinesh, Divya), never retroflex 'ட'
        if (isStart && lower.substring(i, i + consLen) == 'd') {
          matchedConsonant = 'த';
        }

        i += consLen;
        isStart = false;

        // Check if immediately followed by a vowel
        String? matchedDepVowel;
        int vLen = 0;
        for (var len = 2; len >= 1; len--) {
          if (i + len <= lower.length) {
            final sub = lower.substring(i, i + len);
            if (depVowels.containsKey(sub)) {
              matchedDepVowel = depVowels[sub];
              vLen = len;
              // In Indian names ending in 'a' (e.g. Boomika, Deepika, Kavitha, Anitha), final 'a' is long 'ா'
              if (sub == 'a' && i + len == lower.length) {
                matchedDepVowel = 'ா';
              }
              break;
            }
          }
        }

        if (matchedDepVowel != null) {
          buffer.write(matchedConsonant);
          buffer.write(matchedDepVowel);
          i += vLen;
        } else {
          // If no following vowel, it's a pure consonant (virama ்)
          if (!matchedConsonant.endsWith('்') && !matchedConsonant.endsWith('ஸ்ரீ')) {
            buffer.write(matchedConsonant);
            buffer.write('்');
          } else {
            buffer.write(matchedConsonant);
          }
        }
      } else {
        // Character not recognized as consonant or initial vowel
        String? midVowel;
        int mvLen = 0;
        for (var len = 2; len >= 1; len--) {
          if (i + len <= lower.length) {
            final sub = lower.substring(i, i + len);
            if (initVowels.containsKey(sub)) {
              midVowel = initVowels[sub];
              mvLen = len;
              break;
            }
          }
        }
        if (midVowel != null) {
          buffer.write(midVowel);
          i += mvLen;
        } else {
          buffer.write(lower[i]);
          i++;
        }
        isStart = false;
      }
    }

    return buffer.toString();
  }

  /// Transliterates an English name into Tamil.
  static String transliterate(String fullName) {
    if (fullName.trim().isEmpty) return fullName;
    if (hasTamil(fullName)) return fullName;

    final tokens = fullName.split(' ');
    final translatedTokens = <String>[];

    for (final token in tokens) {
      if (token.isEmpty) {
        translatedTokens.add('');
        continue;
      }

      final cleanToken = token.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      final hasDot = token.endsWith('.');

      if (_titles.containsKey(token.toLowerCase())) {
        translatedTokens.add(_titles[token.toLowerCase()]!);
      } else if (cleanToken.length == 1 && _initials.containsKey(cleanToken)) {
        final initialTamil = _initials[cleanToken]!;
        translatedTokens.add(hasDot ? '$initialTamil.' : initialTamil);
      } else if (_dictionary.containsKey(cleanToken)) {
        translatedTokens.add(_dictionary[cleanToken]!);
      } else {
        translatedTokens.add(_transliteratePhonetic(token));
      }
    }

    return translatedTokens.join(' ');
  }

  /// Formats the patient name based on whether the app is currently in Tamil mode.
  /// If [isTamil] is true and [showBoth] is true, returns:
  /// `தமிழ்பெயர் (English Name)`
  /// If [showBoth] is false, returns `தமிழ்பெயர்`.
  /// If [isTamil] is false, returns original [name].
  static String formatName(
    String name, {
    required bool isTamil,
    bool showBoth = true,
  }) {
    if (!isTamil || name.trim().isEmpty) return name;
    final tamil = transliterate(name);
    if (tamil == name || !showBoth) return tamil;
    return '$tamil ($name)';
  }

  /// Convenience method using context to check active locale.
  /// Subscribes to LanguageProvider by default so callers automatically rebuild on toggle.
  static String translate(
    BuildContext context,
    String name, {
    bool showBoth = true,
    bool listen = true,
  }) {
    bool isTamil = false;
    try {
      final langProvider = Provider.of<LanguageProvider>(context, listen: listen);
      isTamil = langProvider.isTamil;
    } catch (_) {
      try {
        isTamil = Localizations.localeOf(context).languageCode == 'ta';
      } catch (_) {}
    }
    return formatName(name, isTamil: isTamil, showBoth: showBoth);
  }
}
