# B-SAFE — Smart City Building Safety App

Flutter application for building safety inspection, defect reporting, AI-powered analysis, and UWB indoor positioning.

---

## Architecture

This project follows **Feature-First Clean Architecture**.

```
lib/
├── core/                          # App-wide infrastructure
│   ├── config/app_config.dart     # API keys, Supabase URL, Gemini model
│   ├── constants/                 # AppColors, AppRoutes
│   ├── di/service_locator.dart    # Dependency injection setup
│   ├── error/                     # Failures, Exceptions
│   ├── network/http_client.dart   # Shared HTTP client
│   ├── providers/                 # ConnectivityProvider, LanguageProvider, NavigationProvider
│   ├── theme/app_theme.dart       # Colors, getRiskColor(), getRiskLabel()
│   ├── usecases/usecase.dart      # Abstract UseCase<T,P> + NoParams
│   └── utils/extensions.dart     # Dart extension methods
│
├── features/
│   ├── ai_analysis/               # Gemini AI image analysis
│   │   ├── data/datasources/ai_remote_datasource.dart
│   │   ├── data/repositories/
│   │   ├── domain/entities/ai_result.dart
│   │   ├── domain/repositories/
│   │   └── domain/usecases/analyze_image.dart
│   │
│   ├── building_medical_record/   # Floor-plan inspection + UWB pin placement
│   │   ├── data/models/           # InspectionModel, ProjectModel
│   │   ├── presentation/pages/    # ProjectListPage, InspectionPage
│   │   └── presentation/providers/inspection_provider.dart
│   │
│   ├── dashboard/                 # Risk statistics & charts
│   │   └── presentation/pages/analysis_page.dart
│   │
│   ├── defect_reporting/          # Full CRUD defect reports + AI analysis
│   │   ├── data/datasources/report_remote_datasource.dart
│   │   ├── data/models/report_model.dart
│   │   ├── data/repositories/
│   │   ├── domain/entities/report.dart      # ConversationMessage defined here
│   │   ├── domain/repositories/
│   │   ├── domain/usecases/                 # GetReports, CreateReport, UpdateStatus, SubmitWorkerResponse
│   │   ├── presentation/pages/              # ReportPage, HistoryPage, ReportDetailPage
│   │   └── presentation/providers/report_provider.dart
│   │
│   ├── home/                      # Quick-report dashboard with AI + floor-plan pin
│   │   └── presentation/pages/home_page.dart
│   │
│   ├── location/                  # UWB indoor positioning
│   │   └── presentation/pages/   # LocationPage, CalibrationPage
│   │
│   ├── notification/              # Worker follow-up messages
│   │   └── presentation/pages/followup_page.dart
│   │
│   ├── surveyor_web/              # Web portal for company surveyors
│   │   └── presentation/pages/   # WebDashboardPage, WebReportDetailPage
│   │
│   └── uwb_positioning/
│       └── data/models/uwb_model.dart  # UwbAnchor, UwbTag, UwbConfig, TrajectoryPoint
│
├── services/                      # Platform / hardware infrastructure services
│   ├── supabase_service.dart       # Cloud sync, real-time, storage
│   ├── uwb_service.dart            # UWB TWR hardware driver
│   ├── desktop_serial_service.dart # PC serial port (flutter_libserialport)
│   ├── mobile_serial_service.dart  # Android serial port (usb_serial)
│   ├── yolo_service.dart           # On-device YOLO crack detection
│   └── word_export_service.dart    # Generate .docx inspection reports
│
├── shared/
│   └── widgets/                   # Reusable UI components used across features
│       ├── ai_analysis_result.dart
│       ├── animated_counter.dart
│       ├── category_selector.dart
│       ├── recent_report_card.dart
│       ├── report_detail_card.dart
│       ├── severity_selector.dart
│       ├── shimmer_loading.dart
│       ├── stat_card.dart
│       ├── uwb_data_tables.dart
│       ├── uwb_position_canvas.dart
│       └── uwb_settings_panel.dart
│
├── main.dart                      # App entry point (mobile)
└── main_web.dart                  # App entry point (web portal)
```

---

## Are `services/` and `shared/widgets/` valid in Feature-First Architecture?

### `lib/shared/widgets/` ✅ Correct placement

Cross-feature UI primitives belong in `shared/`. A widget should only move into a feature folder when it is used by that feature alone and is tightly coupled to its domain logic.

### `lib/services/` ✅ Justified as shared infrastructure

In strict Clean Architecture, datasources live inside each feature's `data/` layer (e.g., `AiRemoteDataSource`). The files in `lib/services/` are kept here because they are **hardware/platform drivers**, not business logic:

| Service | Why it stays in `services/` |
|---|---|
| `supabase_service.dart` | Used by 3+ features; wraps raw Supabase SDK |
| `uwb_service.dart` | Hardware driver used by `location` + `building_medical_record` + shared widgets |
| `desktop_serial_service.dart` | Platform I/O; used by UWB service + 2 features |
| `mobile_serial_service.dart` | Platform I/O for Android |
| `yolo_service.dart` | On-device ML inference, single entry point |
| `word_export_service.dart` | File generation, no business logic |

This is a common and accepted pragmatic decision in Flutter projects with hardware integrations.

---

## Tech Stack

| Concern | Package |
|---|---|
| State management | `provider ^6.1.1` |
| Cloud backend | `supabase_flutter ^2.3.4` |
| AI analysis | Gemini 2.5 Flash (via HTTP) |
| Charts | `fl_chart ^0.66.0` |
| UWB/Serial (desktop) | `flutter_libserialport ^0.6.0` |
| UWB/Serial (mobile) | `usb_serial ^0.5.2` |
| Object detection | `ultralytics_yolo ^0.2.0` |
| Image picker | `image_picker ^1.0.7` |
| File picker | `file_picker ^10.3.10` |
| PDF view | `pdfrx ^2.2.24` |
| Word export | `archive ^4.0.9` |
| Location | `geolocator ^10.1.0` + `geocoding ^2.1.1` |
| Local storage | `shared_preferences ^2.2.2` |
| SVG | `flutter_svg ^2.3.3` |

---

## Key Patterns

**Use-cases** — every business operation goes through a typed use-case:
```dart
// domain/usecases/analyze_image.dart
class AnalyzeImage extends UseCase<Map<String,dynamic>, AnalyzeImageParams> {...}
```

**Providers** — `ChangeNotifier` providers live in `features/<name>/presentation/providers/`. Core app state (connectivity, language, navigation) lives in `core/providers/`.

**Single model source** — `ConversationMessage` is defined in `features/defect_reporting/domain/entities/report.dart`. `ReportModel` is the data-layer extension of `Report`. All services import from feature paths directly.

**AI fallback** — `AiRemoteDataSource.localFallback(severity, category)` provides offline scores when Gemini is unreachable.

---

## Running

```bash
# Mobile (Android/Linux)
flutter run

# Web (surveyor portal)
flutter run -t lib/main_web.dart -d chrome
```

Configure `lib/core/config/app_config.dart` with your Supabase URL, anon key, and Gemini API key before running.
