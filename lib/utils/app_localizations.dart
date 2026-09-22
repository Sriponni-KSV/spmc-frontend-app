import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Navigation
      'dashboard': 'Dashboard',
      'patients': 'Patients',
      'appointments': 'Appointments',
      'doctors': 'Doctors',
      'admission_counter': 'Admission Counter',
      'billing': 'Billing & Invoices',
      'pharmacy': 'Pharmacy',
      'laboratory': 'Laboratory',
      'opd_management': 'OPD Management',
      'ipd_management': 'IPD Management',
      'icu_management': 'ICU Management',
      'ot_management': 'OT Management',
      'inventory': 'Inventory',
      'pending_tests': 'Pending Tests',
      'completed_tests': 'Completed Tests',
      'resources': 'Resources',
      'prescriptions': 'Prescriptions',
      'medicines': 'Medicines',
      'dispense': 'Dispense',
      'reports': 'Reports',
      'staff': 'Staff Management',
      'settings': 'Settings',
      'profile': 'Profile',
      'logout': 'Logout',

      // Actions
      'save': 'Save',
      'cancel': 'Cancel',
      'close': 'Close',
      'submit': 'Submit',
      'edit': 'Edit',
      'delete': 'Delete',
      'search': 'Search',
      'search_anything': 'Search anything...',
      'filter': 'Filter',
      'refresh': 'Refresh',
      'book_appointment': 'Book Appointment',
      'new_patient': 'New Patient',
      'help': 'Help',
      'share': 'Share',
      'back': 'Back',
      'notifications': 'Notifications',

      // Theme & Settings
      'app_settings': 'Application Settings',
      'language': 'Language',
      'select_language': 'Select Language',
      'english': 'English',
      'tamil': 'தமிழ் (Tamil)',
      'theme': 'Theme Mode',
      'light_mode': 'Light',
      'dark_mode': 'Dark',
      'system_default': 'System Default',
      'language_subtitle': 'Choose your preferred interface language',
      'theme_subtitle': 'Adjust appearance according to your preference',
      'theme_mode_applied': 'Theme updated successfully',
      'language_applied': 'Language updated successfully',

      // Information
      'status': 'Status',
      'active': 'Active',
      'today': 'Today',
      'welcome': 'Welcome',
      'total_patients': 'Total Patients',
      'upcoming_appointments': 'Upcoming Appointments',
      'recent_patients': 'Recent Patients',
      'staff_id': 'Staff Unique ID',
      'email_address': 'Email Address',
      'mobile_number': 'Mobile Number',
      'onboarded_date': 'Onboarded Date',
      'role': 'Role',
      'admin': 'Administrator',
      'doctor': 'Doctor',
      'nurse': 'Nurse',
      'front_desk': 'Front Desk',
      'lab_technician': 'Lab Technician',
      'pharmacist': 'Pharmacist',
    },
    'ta': {
      // Navigation
      'dashboard': 'முகப்பு',
      'patients': 'நோயாளிகள்',
      'appointments': 'முன்பதிவுகள்',
      'doctors': 'மருத்துவர்கள்',
      'admission_counter': 'சேர்க்கை பிரிவு',
      'billing': 'கட்டணம் & ரசீதுகள்',
      'pharmacy': 'மருந்தகம்',
      'laboratory': 'ஆய்வகம்',
      'opd_management': 'வெளிநோயாளி பிரிவு',
      'ipd_management': 'உள்நோயாளி பிரிவு',
      'icu_management': 'தீவிர சிகிச்சை பிரிவு',
      'ot_management': 'அறுவை சிகிச்சை அரங்கம்',
      'inventory': 'இருப்பு மேலாண்மை',
      'pending_tests': 'நிலுவை சோதனைகள்',
      'completed_tests': 'முடிந்த சோதனைகள்',
      'resources': 'வளங்கள்',
      'prescriptions': 'மருந்துச் சீட்டுகள்',
      'medicines': 'மருந்துகள்',
      'dispense': 'மருந்து வழங்குதல்',
      'reports': 'அறிக்கைகள்',
      'staff': 'பணியாளர்கள் மேலாண்மை',
      'settings': 'அமைப்புகள்',
      'profile': 'சுயவிவரம்',
      'logout': 'வெளியேறு',

      // Actions
      'save': 'சேமி',
      'cancel': 'ரத்து செய்',
      'close': 'மூடு',
      'submit': 'சமர்ப்பி',
      'edit': 'திருத்து',
      'delete': 'நீக்கு',
      'search': 'தேடுக',
      'search_anything': 'தேடவும்...',
      'filter': 'வடிகட்டு',
      'refresh': 'புதுப்பி',
      'book_appointment': 'முன்பதிவு செய்க',
      'new_patient': 'புதிய நோயாளி',
      'help': 'உதவி',
      'share': 'பகிர்',
      'back': 'பின்னே',
      'notifications': 'அறிவிப்புகள்',

      // Theme & Settings
      'app_settings': 'பயன்பாட்டு அமைப்புகள்',
      'language': 'மொழி',
      'select_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'english': 'English (ஆங்கிலம்)',
      'tamil': 'தமிழ் (Tamil)',
      'theme': 'தீம் பயன்முறை',
      'light_mode': 'வெளிச்சம் (Light)',
      'dark_mode': 'இருள் (Dark)',
      'system_default': 'கணினி இயல்பு (System)',
      'language_subtitle': 'பயன்பாட்டின் மொழியைத் தேர்ந்தெடுக்கவும்',
      'theme_subtitle': 'உங்கள் விருப்பத்திற்கேற்ப தோற்றத்தை மாற்றவும்',
      'theme_mode_applied': 'தீம் வெற்றிகரமாக மாற்றப்பட்டது',
      'language_applied': 'மொழி வெற்றிகரமாக மாற்றப்பட்டது',

      // Information
      'status': 'நிலை',
      'active': 'செயலில்',
      'today': 'இன்று',
      'welcome': 'வரவேற்கிறோம்',
      'total_patients': 'மொத்த நோயாளிகள்',
      'upcoming_appointments': 'வரவிருக்கும் முன்பதிவுகள்',
      'recent_patients': 'சமீபத்திய நோயாளிகள்',
      'staff_id': 'பணியாளர் எண்',
      'email_address': 'மின்னஞ்சல் முகவரி',
      'mobile_number': 'அலைபேசி எண்',
      'onboarded_date': 'சேர்ந்த தேதி',
      'role': 'பதவி',
      'admin': 'நிர்வாகி',
      'doctor': 'மருத்துவர்',
      'nurse': 'செவிலியர்',
      'front_desk': 'வரவேற்பாளர்',
      'lab_technician': 'ஆய்வக வல்லுநர்',
      'pharmacist': 'மருந்தாளர்',
    },
  };

  String translate(String key, {String? fallback}) {
    final langCode = locale.languageCode;
    if (_localizedValues.containsKey(langCode) &&
        _localizedValues[langCode]!.containsKey(key)) {
      return _localizedValues[langCode]![key]!;
    }
    // Fallback to English
    if (_localizedValues['en']!.containsKey(key)) {
      return _localizedValues['en']![key]!;
    }
    return fallback ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationExtension on BuildContext {
  String tr(String key, {String? fallback}) {
    return AppLocalizations.of(this).translate(key, fallback: fallback);
  }
}
