import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/patient_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/admin_dashboard.dart';
import '../../screens/dashboard_page.dart'; // Doctor Dashboard
import '../../screens/forgot_password_page.dart';
import '../../screens/login_page.dart';
import '../../screens/force_change_password_screen.dart';
import '../../screens/nurse_dashboard.dart';
import '../../screens/front_desk_dashboard.dart';
import '../../screens/lab_dashboard.dart';
import '../../screens/pharmacy_dashboard.dart';
import 'route_constants.dart';
import 'screens/not_found_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> parentNavigatorKey =
      GlobalKey<NavigatorState>();

  static GoRouter createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      navigatorKey: parentNavigatorKey,
      initialLocation: AppRoutes.login,
      debugLogDiagnostics: true,
      refreshListenable: authProvider,

      // 🛑 ROUTE GUARDS & DYNAMIC REDIRECTION (Auth & Role-Based Checks)
      redirect: (context, state) {
        final isLoggedIn = authProvider.user != null;
        final goingToPublic = state.matchedLocation == AppRoutes.login ||
            state.matchedLocation == AppRoutes.forgotPassword ||
            state.matchedLocation == AppRoutes.resetPassword ||
            state.matchedLocation == AppRoutes.forceChangePassword;

        // 1. Unauthenticated Users: Redirect to Login
        if (!isLoggedIn) {
          if (!goingToPublic) {
            return AppRoutes.login;
          }
          return null; // Stay on public screen
        }

        // 2. Authenticated Users attempting to access public routes: Redirect to Dashboard
        if (goingToPublic) {
          return AppRoutes.dashboard;
        }

        // 3. Central common route: Redirect to role-specific dashboard
        if (state.matchedLocation == AppRoutes.dashboard) {
          final role = authProvider.user!.role;
          if (role == 'Nurse' || role == 'Head Nurse') {
            return AppRoutes.nurseDashboard;
          } else if (role == 'Admin' ||
              role == 'Supervisor' ||
              role == 'Super Admin') {
            return AppRoutes.adminDashboard;
          } else if (role == 'Front Desk' ||
              role == 'Receptionist' ||
              role == 'Reception') {
            return AppRoutes.receptionDashboard;
          } else if (role == 'Lab') {
            return AppRoutes.labDashboard;
          } else if (role == 'Pharmacy') {
            return AppRoutes.pharmacyDashboard;
          } else {
            return AppRoutes.doctorDashboard; // Default to Doctor dashboard
          }
        }

        // 4. Role-based Route Prefix Guarding
        final userRole = authProvider.user!.role;
        final path = state.matchedLocation;

        if (path.startsWith('/admin')) {
          final isAdmin = userRole == 'Admin' ||
              userRole == 'Supervisor' ||
              userRole == 'Super Admin';
          if (!isAdmin) {
            return AppRoutes.dashboard; // Redirect to user's home dashboard
          }
        } else if (path.startsWith('/nurse')) {
          final isNurse = userRole == 'Nurse' || userRole == 'Head Nurse';
          if (!isNurse) {
            return AppRoutes.dashboard;
          }
        } else if (path.startsWith('/doctor')) {
          final isDoctor = userRole == 'Doctor' || userRole == 'Anaesthetist';
          if (!isDoctor) {
            return AppRoutes.dashboard;
          }
          if ((path == AppRoutes.doctorDictation || path == AppRoutes.doctorLabReports) && userRole == 'Anaesthetist') {
            return AppRoutes.dashboard;
          }
        } else if (path.startsWith('/reception')) {
          // Allow reception routes or redirect (in case reception features are merged with Nurse)
          final isReception = userRole == 'Receptionist' ||
              userRole == 'Reception' ||
              userRole == 'Front Desk' ||
              userRole == 'Nurse' ||
              userRole == 'Head Nurse';
          if (!isReception) {
            return AppRoutes.dashboard;
          }
        } else if (path.startsWith('/lab')) {
          final isLab = userRole == 'Lab';
          if (!isLab) {
            return AppRoutes.dashboard;
          }
        } else if (path.startsWith('/pharmacy')) {
          final isPharmacy = userRole == 'Pharmacy';
          if (!isPharmacy) {
            return AppRoutes.dashboard;
          }
        }

        return null; // Allow access
      },

      // 📡 PUBLIC & PROTECTED ROUTE DEFINITIONS
      routes: [
        // --- Public Routes ---
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: AppRoutes.resetPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: AppRoutes.forceChangePassword,
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return ForceChangePasswordScreen(email: email);
          },
        ),

        // --- Common Protected Route (redirects to role-specific dashboard) ---
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => const SizedBox.shrink(), // Never rendered; always redirected by guard
        ),

        // --- Admin Protected Routes ---
        GoRoute(
          path: AppRoutes.adminDashboard,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 0),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminUsers,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 1),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminPatients,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 2),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminSettings,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 3),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminAppointments,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 4),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminOpd,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 5),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminIpd,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 6),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminOt,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 7),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminShifts,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 8),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminIcu,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 9),
          ),
        ),
        GoRoute(
          path: AppRoutes.adminInventory,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('admin_dashboard'),
            child: AdminDashboardScreen(initialIndex: 11),
          ),
        ),



        // --- Nurse Protected Routes ---
        GoRoute(
          path: AppRoutes.nurseDashboard,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 0),
          ),
        ),
        GoRoute(
          path: AppRoutes.nursePatients,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 1),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseNewPatient,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(
              initialIndex: 1,
              isRegisteringPatient: true,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseEditPatient,
          pageBuilder: (context, state) => NoTransitionPage(
            key: const ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(
              initialIndex: 1,
              isRegisteringPatient: true,
              existingPatient: state.extra as PatientModel?,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseAppointments,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 2),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseBookAppointment,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(
              initialIndex: 2,
              forceBooking: true,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseDoctors,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 3),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseProfile,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 4),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseOpd,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 5),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseIpd,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 6),
          ),
        ),
        GoRoute(
          path: AppRoutes.nurseOt,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('nurse_dashboard'),
            child: NurseDashboardScreen(initialIndex: 7),
          ),
        ),

        // --- Lab Protected Routes ---
        GoRoute(
          path: AppRoutes.labDashboard,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('lab_dashboard'),
            child: LabDashboardScreen(initialIndex: 0),
          ),
        ),

        // --- Pharmacy Protected Routes ---
        GoRoute(
          path: AppRoutes.pharmacyDashboard,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('pharmacy_dashboard'),
            child: PharmacyDashboardScreen(initialIndex: 0),
          ),
        ),

        // --- Doctor Protected Routes ---
        GoRoute(
          path: AppRoutes.doctorDashboard,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 0),
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorPatients,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 1),
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorConsultation,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 1),
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorIpd,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 3),
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorOt,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 4),
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorDictation,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 5),
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorLabReports,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 6),
          ),
        ),
        GoRoute(
          path: AppRoutes.doctorProfile,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('doctor_dashboard'),
            child: DashboardScreen(initialIndex: 2),
          ),
        ),

        // --- Reception Protected Routes ---
        GoRoute(
          path: AppRoutes.receptionDashboard,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 0),
          ),
        ),
        GoRoute(
          path: AppRoutes.receptionAppointments,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 2),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskPatients,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 1),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskNewPatient,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 1, isRegisteringPatient: true),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskEditPatient,
          pageBuilder: (context, state) => NoTransitionPage(
            key: const ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(
              initialIndex: 1,
              isRegisteringPatient: true,
              existingPatient: state.extra as PatientModel?,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskBookAppointment,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 2, forceBooking: true),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskAppointments,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 2),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskDoctors,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 3),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskAdmissionCounter,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 4),
          ),
        ),
        GoRoute(
          path: AppRoutes.frontDeskProfile,
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('reception_dashboard'),
            child: FrontDeskDashboardScreen(initialIndex: 5),
          ),
        ),
      ],

      // 🔍 404 UNKNOWN ROUTE HANDLING
      errorBuilder: (context, state) => const NotFoundScreen(),
    );
  }
}
