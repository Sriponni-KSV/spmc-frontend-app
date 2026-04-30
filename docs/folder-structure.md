Frontend:
lib/
│
├── controllers/                # feature-based inside
│   ├── auth/
│   │   └── auth_controller.dart
│   │
│   ├── doctor/
│   │   └── doctor_controller.dart
│   │
│   ├── patient/
│   │   └── patient_controller.dart
│   │
│   ├── appointment/
│   │   └── appointment_controller.dart
│
├── models/                     # data models
│   ├── user_model.dart
│   ├── doctor_model.dart
│   ├── patient_model.dart
│   └── appointment_model.dart
│
├── screens/                    # UI (feature-based inside)
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   │
│   ├── doctor/
│   │   ├── doctor_dashboard.dart
│   │   └── doctor_profile.dart
│   │
│   ├── patient/
│   │   ├── patient_dashboard.dart
│   │   └── patient_history.dart
│   │
│   └── common/
│       └── splash_screen.dart
│
├── widgets/                    # reusable widgets
│   ├── custom_button.dart
│   ├── custom_input.dart
│   └── loader.dart
│
├── utils/                      # shared logic
│   ├── api_service.dart        # API calls
│   ├── constants.dart
│   ├── helpers.dart
│   └── validators.dart
│
├── main.dart



Admin sidebar:
Dashboard
- Overview
- Analytics
- Daily Summary

Patient Management
- Patient List
- Add Patient
- Patient Profile
- Medical History

Doctor Management
- Doctor List
- Add Doctor
- Specializations
- Doctor Schedule

Appointment Management
- All Appointments
- Book Appointment
- Calendar View
- Time Slots

OPD / IPD Management
- OPD Visits
- IPD Admissions
- Bed Allocation
- Discharge

EMR / Clinical
- Medical Records
- Prescriptions
- Vitals
- Clinical Notes
- Diagnosis

Lab & Diagnostics
- Lab Tests
- Test Requests
- Reports
- Radiology

Pharmacy & Inventory
- Medicines
- Stock Management
- Suppliers
- Purchase Orders
- Pharmacy Billing

Billing & Accounts
- Invoices
- Payments
- Insurance Claims
- Service Charges
- Financial Reports

Staff & HR
- Staff List
- Roles & Permissions
- Attendance
- Payroll

Facility Management
- Wards / Rooms
- Bed Management
- Ambulance
- Duty Roster

Reports
- Patient Reports
- Revenue Reports
- Appointment Reports
- Inventory Reports

Communication
- Notifications
- SMS / Email Logs

Settings & System
- Hospital Profile
- Departments
- Master Data
- System Settings
- Audit Logs

User & Security
- Users
- Roles
- Permissions
- Access Logs

