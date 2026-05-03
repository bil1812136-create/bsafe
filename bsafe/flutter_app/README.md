# B-SAFE Flutter App

B-SAFE is a smart building safety platform built with Flutter. It includes:

- A mobile app for on-site workers to report issues with AI-assisted risk assessment.
- A web dashboard for company staff to review reports, update status, and send follow-up messages.

Both clients share data through Supabase.

## Key Features

### Mobile App (lib/main.dart)
- Create safety reports with title, description, category, severity, and optional image.
- AI analysis (online) with local fallback logic (offline/unavailable AI).
- Risk classification (`low`, `medium`, `high`) with risk score and urgent flag.
- GPS location capture.
- Report history and detail view.
- Worker follow-up response flow (text + optional image).
- Status update (typically `pending` / `in_progress` on worker side).
- Manual offline mode toggle and connectivity indicator.
- Building inspection module (UWB-related workflow, projects, floor plans, defects).

### Web Dashboard (lib/main_web.dart)
- Report list and dashboard-style management view.
- Detailed report view with status updates.
- Company-to-worker follow-up messaging.
- Shared cloud data with the mobile app through Supabase.

### Synchronization
- Reports are persisted in Supabase (`reports` table).
- Report detail updates are auto-refreshed using polling in `RealtimeService` (every 5 seconds).

## Tech Stack

- Flutter
- Provider (state management)
- Supabase (database + storage)
- HTTP APIs for AI analysis
- `ultralytics_yolo` for object detection integration
- `sqflite` is present in the project for legacy/offline support patterns

## Project Structure

```text
flutter_app/
├── lib/
│   ├── main.dart                    # Mobile entry point
│   ├── main_web.dart                # Web dashboard entry point
│   ├── models/                      # Domain models (report, inspection, project, uwb)
│   ├── providers/                   # App state and business flow
│   ├── services/                    # Supabase, AI API, realtime polling, UWB, export
│   ├── screens/                     # Mobile screens + web screens
│   ├── widgets/                     # Reusable UI components
│   └── theme/                       # App theme
├── assets/
├── android/
├── web/
└── pubspec.yaml
```

## Prerequisites

- Flutter SDK (stable channel)
- Dart SDK (compatible with the Flutter version)
- Android Studio / Android SDK for Android builds
- Chrome for web development
- A Supabase project

Check your environment:

```bash
flutter doctor
```

## Setup

### 1) Install dependencies

```bash
flutter pub get
```

### 2) Configure Supabase

This project reads Supabase constants from:

- `lib/services/supabase_service.dart`

Update these values if you are using your own project:

- `supabaseUrl`
- `supabaseAnonKey`

### 3) Database schema (minimum required)

Run the following SQL in Supabase SQL Editor:

```sql
CREATE TABLE IF NOT EXISTS reports (
  id                    BIGSERIAL PRIMARY KEY,
  local_id              INTEGER,
  title                 TEXT NOT NULL,
  description           TEXT NOT NULL,
  category              TEXT NOT NULL,
  severity              TEXT NOT NULL,
  risk_level            TEXT DEFAULT 'low',
  risk_score            INTEGER DEFAULT 0,
  is_urgent             BOOLEAN DEFAULT FALSE,
  status                TEXT DEFAULT 'pending',
  image_url             TEXT,
  image_base64          TEXT,
  location              TEXT,
  latitude              DOUBLE PRECISION,
  longitude             DOUBLE PRECISION,
  ai_analysis           TEXT,
  company_notes         TEXT,
  worker_response       TEXT,
  worker_response_image TEXT,
  conversation          JSONB,
  has_unread_company    BOOLEAN DEFAULT FALSE,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(local_id)
);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS allow_all ON reports;
CREATE POLICY allow_all
ON reports
FOR ALL
USING (true)
WITH CHECK (true);
```

### 4) Storage buckets

Create these Supabase Storage buckets as `Public`:

- `report-images`
- `floor-plans`

### 5) Optional inspection table

If you use the inspection module, create this table:

```sql
CREATE TABLE IF NOT EXISTS inspection_sessions (
  session_id      TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  project_id      TEXT,
  floor           INTEGER DEFAULT 1,
  floor_plan_path TEXT,
  status          TEXT DEFAULT 'active',
  payload         JSONB NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE inspection_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inspection_sessions_allow_all ON inspection_sessions;
CREATE POLICY inspection_sessions_allow_all
ON inspection_sessions
FOR ALL
USING (true)
WITH CHECK (true);
```

## Run the App

### Mobile app (Android)

```bash
flutter run -d android

flutter run -d R5CR30PFFTN --dart-define=GEMINI_API_KEY=YOUR_KEY
```

Or specify a device ID:

```bash
flutter devices
flutter run -d <R5CR30PFFTN>
```
# mobile app flutter run
flutter run -d chrome --target lib/main.dart --dart-define=GEMINI_API_KEY=AIz

# ai api app
cd "C:\bsafe-1\ai api app"
$env:GEMINI_API_KEY="xxxxxxxx"
flutter run -d chrome --dart-define="GEMINI_API_KEY=$env:GEMINI_API_KEY"


### Web dashboard

```bash
flutter run -d chrome --target lib/main_web.dart
```

### Build web

```bash
flutter build web --target lib/main_web.dart
```

## Main Workflows

### Worker report flow
1. Create report in the mobile app.
2. Optional AI analysis enriches category/risk result.
3. Report is saved to Supabase.
4. Company reviews and updates status in web dashboard.
5. Worker and company exchange follow-up messages in report detail.

### Follow-up updates
- Company messages are saved in `conversation` and mark unread flags.
- Worker views details and can clear unread state.
- UI refresh is driven by periodic polling in `RealtimeService`.

## Important Notes

- `ReportProvider` currently loads report data from Supabase.
- If Supabase config is missing/invalid, cloud features are unavailable.
- The app includes both modern cloud flows and some legacy service files.

## Common Commands

```bash
# Get packages
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean build artifacts
flutter clean
```

## Troubleshooting

### Push rejected (non-fast-forward)
If Git push is rejected because your branch is behind remote:

```bash
git pull --rebase origin <branch>
git push origin <branch>
```

If you intentionally want to discard local changes and match remote:

```bash
git fetch origin
git reset --hard origin/<branch>
git clean -fd
```

### Supabase errors
- Confirm URL/key in `lib/services/supabase_service.dart`.
- Verify the `reports` table exists.
- Verify RLS policy allows required operations.
- Verify storage buckets are created.

## License

This project currently has no explicit license file in this directory. Add a `LICENSE` file if you plan to distribute it.
