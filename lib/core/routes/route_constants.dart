class AppRoutes {
  // Public Routes
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String forceChangePassword = '/force-change-password';

  // Common Protected Routes
  static const String dashboard = '/dashboard';

  // Admin Routes
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminPatients = '/admin/patients';
  static const String adminSettings = '/admin/settings';
  static const String adminAppointments = '/admin/appointments';
  static const String adminOpd = '/admin/opd';
  static const String adminIpd = '/admin/ipd';
  static const String adminOt = '/admin/ot';
  static const String adminShifts = '/admin/shifts';
  static const String adminIcu = '/admin/icu';
  static const String adminPharmacy = '/admin/pharmacy';
  static const String adminInventory = '/admin/inventory';


  // Nurse Routes
  static const String nurseDashboard = '/nurse/dashboard';
  static const String nursePatients = '/nurse/patients';
  static const String nurseNewPatient = '/nurse/patients/new-patient';
  static const String nurseAppointments = '/nurse/appointments';
  static const String nurseBookAppointment = '/nurse/appointments/book';
  static const String nurseDoctors = '/nurse/doctors';
  static const String nurseProfile = '/nurse/profile';
  static const String nurseOpd = '/nurse/opd';
  static const String nurseIpd = '/nurse/ipd';
  static const String nurseOt = '/nurse/ot';

  // Doctor Routes
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorConsultation = '/doctor/consultation';
  static const String doctorIpd = '/doctor/ipd';
  static const String doctorProfile = '/doctor/profile';
  static const String doctorOt = '/doctor/ot';
  static const String doctorDictation = '/doctor/dictation';

  // Reception & Front Desk Routes
  static const String receptionDashboard = '/reception/dashboard';
  static const String receptionAppointments = '/reception/appointments';
  static const String frontDeskPatients = '/reception/patients';
  static const String frontDeskNewPatient = '/reception/patients/new-patient';
  static const String frontDeskBookAppointment = '/reception/appointments/book';
  static const String frontDeskAppointments = '/reception/appointments-desk';
  static const String frontDeskDoctors = '/reception/doctors';
  static const String frontDeskAdmissionCounter = '/reception/admission-counter';
  static const String frontDeskProfile = '/reception/profile';
}
