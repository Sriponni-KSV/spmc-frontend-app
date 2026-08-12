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
  static const String adminUsers = '/admin/staff-management';
  static const String adminViewStaff = '/admin/staff-management/view';
  static const String adminPatients = '/admin/patients';
  static const String adminNewPatient = '/admin/patients/new-patient';
  static const String adminEditPatient = '/admin/patients/edit';
  static const String adminViewPatient = '/admin/patients/view';
  static const String adminSettings = '/admin/access-control';
  static const String adminAppointments = '/admin/appointments';
  static const String adminOpd = '/admin/opd-management';
  static const String adminIpd = '/admin/ipd-management';
  static const String adminOt = '/admin/ot-management';
  static const String adminShifts = '/admin/shift-allocation';
  static const String adminIcu = '/admin/icu-emergency';
  static const String adminPharmacy = '/admin/pharmacy';
  static const String adminInventory = '/admin/inventory-management';
  static const String adminBilling = '/admin/billing';
  static const String adminHomeVisits = '/admin/home-visits';
  static const String adminMedicationCatalog = '/admin/medication-catalog';
  static const String adminHomeVisitConsumables = '/admin/home-visit-consumables';
  static const String adminCarriedKitItems = '/admin/carried-kit-items';


  // Nurse Routes
  static const String nurseDashboard = '/nurse/dashboard';
  static const String nursePatients = '/nurse/patients';
  static const String nurseNewPatient = '/nurse/patients/new-patient';
  static const String nurseEditPatient = '/nurse/patients/edit';
  static const String nurseViewPatient = '/nurse/patients/view';
  static const String nurseAppointments = '/nurse/appointments';
  static const String nurseBookAppointment = '/nurse/appointments/book';
  static const String nurseDocAppointments = '/nurse/doc-appointments';
  static const String nurseDoctors = '/nurse/doctors';
  static const String nurseProfile = '/nurse/profile';
  static const String nurseProfileEdit = '/nurse/profile/edit';
  static const String nurseOpd = '/nurse/opd-assistance';
  static const String nurseIpd = '/nurse/ipd-management';
  static const String nurseIpdMonitoring =
      '/nurse/ipd-management/nursing-station';
  static const String nurseOt = '/nurse/ot-management';
  static const String nurseHomeVisits = '/nurse/home-visits';
  static const String nurseHomeVisitExecute = '/nurse/home-visits/execute/:id';
  static const String nurseHomeVisitSummary = '/nurse/home-visits/summary/:id';

  // Doctor Routes
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorDashboardConsultation =
      '/doctor/dashboard/consultation';
  static const String doctorPatients = '/doctor/consultations';
  static const String doctorConsultation = '/doctor/consultations';
  static const String doctorConsultationSession =
      '/doctor/consultations/session';
  static const String doctorConsultationsEdit = '/doctor/consultations/edit';
  static const String doctorIpd = '/doctor/ipd-management';
  static const String doctorIpdMonitoring = '/doctor/ipd-management/monitoring';
  static const String doctorProfile = '/doctor/profile';
  static const String doctorProfileEdit = '/doctor/profile/edit';
  static const String doctorOt = '/doctor/ot-management';
  static const String doctorDictation = '/doctor/ai-dictation';
  static const String doctorLabReports = '/doctor/lab-reports';

  // Reception & Front Desk Routes
  static const String receptionDashboard = '/reception/dashboard';
  static const String receptionAppointments = '/reception/appointments';
  static const String frontDeskPatients = '/reception/patients';
  static const String frontDeskNewPatient = '/reception/patients/new-patient';
  static const String frontDeskEditPatient = '/reception/patients/edit';
  static const String frontDeskViewPatient = '/reception/patients/view';
  static const String frontDeskBookAppointment = '/reception/appointments/book';
  static const String frontDeskAppointments = '/reception/appointments';
  static const String frontDeskDoctors = '/reception/doctors';
  static const String frontDeskAdmissionCounter =
      '/reception/admission-counter';
  static const String frontDeskBilling = '/reception/billing';
  static const String frontDeskProfile = '/reception/profile';
  static const String frontDeskProfileEdit = '/reception/profile/edit';

  // Lab Routes
  static const String labDashboard = '/lab/dashboard';
  static const String labPending = '/lab/pending-tests';
  static const String labCompleted = '/lab/completed-tests';
  static const String labProfile = '/lab/profile';
  static const String labResources = '/lab/resources';
  static const String labBilling = '/lab/billing';

  // Pharmacy Routes
  static const String pharmacyDashboard = '/pharmacy/dashboard';
  static const String pharmacyInventory = '/pharmacy/inventory';
  static const String pharmacyProfile = '/pharmacy/profile';
  static const String pharmacyBilling = '/pharmacy/billing';
}
