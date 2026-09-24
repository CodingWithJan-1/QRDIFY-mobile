# QRDify Mobile

Flutter client for the QRDify Student and Parent modules.

## Visual identity

The mobile interface follows the existing TWCES web application. It uses the
bundled **Inter** variable font, the school logo from
`assets/images/logo/school logo.jpg`, primary navy `#0B3A82`, secondary blue
`#154FA3`, accent yellow `#FFD22E`, and slate background `#F8FAFC`. Android,
iOS, and the Flutter startup screen use the school logo on the navy background.

## Project structure

The app uses a feature-first structure so each module owns its behavior and UI.

```text
lib/
  app/                 App setup and navigation
  core/                Cross-cutting configuration, networking, storage, and theme
  features/
    auth/               Authentication and portal access
    student/            Student-specific behavior and screens
    parent/             Parent-specific behavior and screens
  shared/              Reusable UI with no feature-specific business rules
```

As features are implemented, each feature may contain `data`, `domain`, and
`presentation` folders. Widgets call their presentation controller; controllers
depend on domain repositories; data repositories handle API and local storage.
Feature code should not import presentation code from another feature.

The entry point in `lib/main.dart` only initializes Flutter and starts the app.
Authentication gating and app-wide navigation live under `lib/app`, and the
global visual theme lives in `lib/core/theme`.

## API configuration

The app uses the deployed QRDify API by default in release builds and the Android
emulator API during debug development. Pass the complete base URL when needed:

```powershell
flutter run --dart-define=API_BASE_URL=https://school.example/api
```

Debug builds default to `http://10.0.2.2:8000/api`. Release builds default to
`https://qridify.online/api`. Use the computer's reachable LAN address for a
physical device running a local backend.

Authentication tokens and the generated installation ID are stored with
`flutter_secure_storage`. The app never embeds SMTP, database, or Laravel secrets.

In the default compatibility mode, the current implementation uses:

- `POST /login`
- `GET /me`
- `POST /logout`
- `GET /student/dashboard?month=YYYY-MM`
- `GET /student/geofence-policy` when the hybrid geofence backend is deployed
- `POST /student/location` as the deployed-server compatibility fallback
- `GET /mobile/v1/parent/children`
- `GET /mobile/v1/parent/children/{childId}/dashboard`
- `GET /mobile/v1/parent/children/{childId}/attendance`
- `GET /mobile/v1/parent/children/{childId}/absences`
- `POST /mobile/v1/parent-invitations/verification`
- `POST /mobile/v1/parent-invitations/accept`

Dedicated mobile authentication routes are implemented. Keep the app-wide mobile
API flag disabled in the current production candidate because Student dashboard,
attendance, schedules, and notifications still use compatibility endpoints. The
location repository independently uses `/api/mobile/v1/student/*` for consent,
policy, and idempotent samples. A future all-mobile build will use:

```powershell
flutter run --dart-define=USE_MOBILE_API=true `
  --dart-define=API_BASE_URL=https://school.example/api/mobile/v1
```

Parent reads and invitation enrollment use the same `/api` base URL and the
`/api/mobile/v1` namespace.

## Current implementation

Available against the existing Laravel API:

- Student login, restored session, logout, and dashboard
- Persistent Student bottom navigation for Home, Attendance, Schedule, Excuses,
  and Alerts
- Paginated Student attendance history
- Student schedule list, create, edit, and delete
- Shared notification inbox, mark-one, mark-all, and legacy deletion
- Student excuse-letter history, multipart submission, optional JPG/PNG/PDF
  attachment, and deletion through the existing Laravel workflow
- Explicit campus-location consent and sharing with a fresh sample approximately
  every 15 minutes, Android foreground-service visibility, server-enforced school
  windows, and controls under Account -> Location & privacy
- Parent linked-child selection, overview, attendance, recorded absences, and
  alerts with child-scoped authorization
- Parent invitation token, email verification code, and account creation flow
- Attendance email delivery to eligible linked Parent accounts, with the legacy
  Student guardian email retained only for records without Parent links

Native push, Parent location history, Parent excuse submission, and a durable
offline location queue stay disabled until their backend contracts are live.
Invitation delivery requires configured backend mail and queue services.
See `development-report.md` for the current access and setup blockers.

## Android production build

The production application ID is `online.qridify.twces`. Release builds refuse
to use Flutter's debug key.

1. Create a permanent Android release keystore, back it up securely, and keep it
   outside version control. All future updates must use the same key.
2. Copy `android/key.properties.example` to `android/key.properties` and fill in
   the real keystore path, alias, and passwords.
3. Build the directly distributable APK with the compatibility API base:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release `
  --dart-define=API_BASE_URL=https://qridify.online/api `
  --dart-define=USE_MOBILE_API=false
```

Release builds reject non-HTTPS API URLs. The output is
`build/app/outputs/flutter-apk/app-release.apk`.

Before distribution, install this release APK on a clean test phone, verify an
in-place update from the previous school release, and publish its SHA-256
checksum with the version number. Distribute it from a school-controlled HTTPS
download page or managed-device channel.

The iOS bundle ID is also `online.qridify.twces`. An Apple Developer team,
provisioning profile, archive build, and physical-device review must be completed
on macOS before App Store distribution.
