class AppRoutes {
  // Public Routes
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

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

  // Doctor Routes
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorConsultation = '/doctor/consultation';
  static const String doctorProfile = '/doctor/profile';

  // Reception Routes
  static const String receptionDashboard = '/reception/dashboard';
  static const String receptionAppointments = '/reception/appointments';
}
