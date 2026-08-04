# Sri Ponni Medical Dashboard - Frontend Style Guide

This document defines the design system, typography, color palette, button styles, form fields, and character/validation constraints for the Sri Ponni frontend application. All UI updates and new components must adhere to this guide.

---

## 1. Core Tech Stack
* **Framework:** Flutter (configured with Material 3: `useMaterial3: true`)
* **Default Theme:** Defined in `AppTheme` within [app_theme.dart](file:///c:/sriPonni/spmc-frontend-app/lib/utils/app_theme.dart).
* **State Management:** Provider pattern.
* **Routing:** `go_router`.

---

## 2. Typography System
We use the **Inter** font family from Google Fonts for a modern, clean, and highly readable look.

| Style Name | Font Size | Weight | Color | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `displayLarge` | 28px (up to 36px on web) | Bold (700) | `textPrimaryColor` | Large headers (e.g., Auth Headers, Dashboard Titles) |
| `headlineMedium` | 22px | Semi-Bold (600) | `textPrimaryColor` | Screen titles & section headings |
| `titleMedium` | 18px | Medium (500) | `textPrimaryColor` | Subheadings & card headers |
| `bodyLarge` | 16px | Normal (400) | `textPrimaryColor` | Standard primary body text |
| `bodyMedium` | 14px | Normal (400) | `textPrimaryColor` | Secondary body text & form field content |
| `bodySmall` | 12px | Normal (400) | `textMutedColor` / `textSecondary` | Captions, small notes, and timestamp labels |
| `labelLarge` | 14px | Semi-Bold (600) | `textPrimaryColor` | Table headers, buttons, & strong labels |

---

## 3. Color Palette

### 3.1 Brand & Neutral Colors
* **Primary (Logo Blue):** `Color(0xFF065D96)` - Primary branding, headers, active focus states, primary buttons.
* **Secondary (Logo Green):** `Color(0xFF79B649)` - Accent branding, success notifications, secondary buttons.
* **Danger/Alert (Logo Red):** `Color(0xFFE53E3E)` - Destructive buttons, validation errors, danger badges.
* **Primary Light:** `Color(0xFFEAF2F7)` - Highlight background.
* **Background:** `Color(0xFFF1F7FB)` - Main scaffold background (subtle blue-tinted gray).
* **Card/Surface Background:** `Colors.white` - Cards, dialog overlays, containers.
* **Border Color:** `Color(0xFFE2E8F0)` - Input field borders, container outlines, dividers.

### 3.2 Semantic Notification Colors
* **Success:** Green `Color(0xFF79B649)` / Bg: `Color(0xFFF1F8EB)`
* **Info:** Blue `Color(0xFF065D96)` / Bg: `Color(0xFFEAF2F7)`
* **Warning:** Amber/Orange `Color(0xFFDD6B20)` / Bg: `Color(0xFFFFFAF0)`
* **Danger:** Red `Color(0xFFE53E3E)` / Bg: `Color(0xFFFFF5F5)`

### 3.3 Dynamic Status Badge Colors
Status indicators dynamically update their styling according to the state of the entity:

| Status Name | Background Color | Text Color |
| :--- | :--- | :--- |
| **Confirmed** | `Color(0xFFDBEAFE)` | `Color(0xFF1E40AF)` |
| **Waiting** | `Color(0xFFFEF3C7)` | `Color(0xFF92400E)` |
| **In Consultation** | `Color(0xFFEDE9FE)` | `Color(0xFF5B21B6)` |
| **Completed** | `Color(0xFFDCFCE7)` | `Color(0xFF166534)` |
| **Cancelled** | `Color(0xFFFEE2E2)` | `Color(0xFF991B1B)` |
| **No-Show** | `Color(0xFFF3F4F6)` | `Color(0xFF374151)` |

---

## 4. Layout & Spacing Constants
To keep the dashboard consistent:
* **Border Radius:**
  * Cards / Buttons / Containers: `12.0` (Double)
  * Text Fields / Inputs: `10.0` (Double)
* **Padding:**
  * Small: `8.0` (e.g., margins between elements, small internal spacing)
  * Medium: `16.0` (standard padding for lists, table padding, columns)
  * Large: `24.0` (outer screen padding, large spacing sections)
* **Card Elevation:** `0.0` (We use a flat design with border and soft drop shadow).
* **Drop Shadow (Card Shadow):**
  ```dart
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  ```

---

## 5. Buttons

Buttons must use standard heights and theme mappings:
* **Height:**
  * Action / Navigation Buttons: `52px` to `56px` minimum height.
  * Dialog Action / Standard Buttons: `48px` minimum height.
* **Shape:** Rounded rectangle with `borderRadius: 12.0`.
* **Padding:** `EdgeInsets.symmetric(horizontal: 20, vertical: 14)`.

### 5.1 Primary Button
* **Bg Color:** `primaryColor` (0xFF065D96)
* **Text Color:** `Colors.white`
* **Theme Helper:** `AppTheme.primaryButton`
* **Usage:** Core submittals, confirmations, logins, and call-to-actions.

### 5.2 Secondary Button
* **Bg Color:** `secondaryColor` (0xFF79B649)
* **Text Color:** `Colors.white`
* **Theme Helper:** `AppTheme.secondaryButton`
* **Usage:** Secondary workflow actions (e.g., secondary options, auxiliary dashboard triggers).

### 5.3 Destructive / Danger Button
* **Bg Color:** `dangerColor` (0xFFE53E3E)
* **Text Color:** `Colors.white`
* **Theme Helper:** `AppTheme.dangerButton`
* **Usage:** Deletion actions, discharge, cancellations.

### 5.4 Outlined Button
* **Text/Border Color:** `primaryColor` (0xFF065D96) / Border: `borderColor` (0xFFE2E8F0)
* **Theme Helper:** `AppTheme.outlinedButton`
* **Usage:** Tertiary actions, optional fields, toggling views.

### 5.5 Cancel Button
* **Text/Border Color:** `textSecondaryColor` (0xFF718096) / Border: `Color(0xFFB0BCC7)`
* **Theme Helper:** `AppTheme.cancelButton`
* **Usage:** Standard cancellation/back button inside dialogs and wizards.

---

## 6. Form Fields & Input Fields

### 6.1 Layout Pattern (Labels + Inputs)
Instead of relying strictly on embedded `labelText` within input decorations, forms should employ external, structured labels:
```dart
Widget _buildLabel(String label) {
  final bool hasStar = label.endsWith(' *');
  final String baseText = hasStar ? label.substring(0, label.length - 2) : label;

  return Padding(
    padding: const EdgeInsets.only(bottom: 10.0),
    child: RichText(
      text: TextSpan(
        text: baseText,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          fontFamily: 'Inter',
        ),
        children: [
          if (hasStar)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    ),
  );
}
```

### 6.2 InputDecoration Decoration Style
All text input elements must implement the `AppTheme.standardInputDecoration()` or adhere to the following setup:
* **Background Fill:** `Color(0xFFF1F5F9)` (Soft off-white / light slate)
* **Internal Padding:** `EdgeInsets.symmetric(horizontal: 16, vertical: 14)`
* **Borders:**
  * Enabled Border: No border (`BorderSide.none`), `borderRadius: 10.0`
  * Focused Border: Primary Blue outline (`width: 1.4`), `borderRadius: 10.0`
  * Error / Focused Error Border: Danger Red outline (`width: 1.5`), `borderRadius: 10.0`
* **Suffix Icons:** Arrow icons or input icons must utilize a soft gray tint `Color(0xFFCBD5E0)` and size `18` or `22`.
* **Validation Mode:** Use `AutovalidateMode.onUserInteraction` to trigger prompt, inline validation feedback.

---

## 7. Form Validation & Character Limits

To maintain database and operational consistency, use the following validation and formatting rules:

### 7.1 Text Fields & Formatting

| Field Name | Min Length | Max Length | Allowed Character Pattern | Validation Logic |
| :--- | :--- | :--- | :--- | :--- |
| **Patient Full Name** | 3 chars | 30 chars | `[a-zA-Z\s]` (Alphabets & spaces only) | Reject numbers/symbols. Mandatory field check. |
| **Email Address** | N/A | 254 chars | Valid Email Format | Match regex: `^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$`. |
| **Mobile Number** | 10 chars | 10 chars | `[0-9]` (Digits only) | Must be exactly 10 digits. |
| **Relationship / Relation** | N/A | 20 chars | `[a-zA-Z\s]` (Alphabets & spaces only) | Standard relation text. |
| **Pincode / Zip** | 6 chars | 6 chars | `[0-9]` (Digits only) | Match postal constraints. |
| **Password** | 8 chars | 16 chars | Mixed Alpha-numeric & Special | Must contain: 1 lowercase, 1 uppercase, 1 digit, 1 special char. |

### 7.2 Medical Vitals Validation Checks

Vitals must have strict boundary conditions to avoid data entry issues:

| Vital Type | Valid Range | Type Constraint | Validation Error Rule |
| :--- | :--- | :--- | :--- |
| **Systolic BP** | 90 - 300 mmHg | Integer (Non-zero) | Must be between 90 and 300 mmHg |
| **Diastolic BP** | 50 - 180 mmHg | Integer (Non-zero) | Must be between 50 and 180 mmHg |
| **Sugar Level** | 30 - 600 mg/dL | Double/Number (Non-zero) | Must be between 30 and 600 mg/dL |
| **Temperature** | 90 - 115 °F | Double/Number (Non-zero) | Must be between 90 and 115 °F |
| **Height** | > 0 | Double/Number | Height must be positive and non-zero |
| **Weight** | > 0 | Double/Number | Weight must be positive and non-zero |

---

## 8. Best Practices for Developers and Coding Assistants
1. **Never Hardcode Colors:** Use `AppTheme.primaryColor`, `AppTheme.secondaryColor`, etc., instead of `Colors.blue` or `Color(0xFF...)`.
2. **Utilize Formatters:** Always append appropriate input formatters to enforce limits in real-time:
   * Digits only: `FilteringTextInputFormatter.digitsOnly`
   * Letters only: `FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))`
   * Length constraints: `LengthLimitingTextInputFormatter(LIMIT)`
3. **Dropdown Handling:** Wrap dropdown fields in safety checks (e.g. ensure selected value exists in dropdown list items) to prevent Flutter crash cycles during updates.
4. **Ensure Responsive Columns:** Use `LayoutBuilder` or layout checks (`constraints.maxWidth > 900`) to stack input rows vertically on mobile/tablet viewports and display side-by-side rows on desktop views.
