# Mobile attendance and alerts: 1.1.6+8

## Attendance contract

The mobile app displays server attendance decisions. It does not apply principal
cutoffs, infer an exit from a missing scan, or grant afternoon attendance itself.
Keep those rules in the backend attendance policy and finalizer.

Include nullable `am_status` and `pm_status` on student and parent attendance
records and dashboard `today` objects. The compatibility student dashboard reads
these fields from today's record in `history`. Supported session labels include
`pending`, `present`, `early`, `late`, `absent`, and `excused`.

When exactly one session is `absent` and the other is `present`, `early`, or
`late`, the app displays Half-day alongside the explicit AM/PM results. A missing
session displays Pending; it never becomes Absent on the phone. Older responses
without session fields retain their daily status and times.

Use daily `status: half_day` for half-day records and return a `half_day` count
alongside existing summary/totals fields. The app accepts this count in student
attendance summaries, mobile student dashboard totals, parent attendance
summaries, and parent dashboard totals. The compatibility student dashboard
counts daily `half_day` records in its returned history, like its existing late
and excused counts. Return all relevant history or migrate this endpoint to
explicit server totals before relying on complete monthly counts.

The matching backend refactor is now prepared locally in
`C:/dev/work/system2/qrdifyv2-mobile-qa-20261015`; its rollout instructions are in
`docs/attendance-sessions-deployment.md` in that checkout. It supplies the AM/PM
contract, half-day totals, lunch rules, reports, and parent alerts. Deployment is
still required. Existing historical check-ins are not bulk rewritten.

## Notifications

Student and parent Alerts icons show a red dot while their inbox has unread
notifications. The parent Children screen also has an account-wide inbox bell;
inside a child workspace, the badge is scoped to that child. Inbox items retain
a red dot until successfully marked read. Badges refresh after successful read,
read-all, and delete operations, on push receipt and app resume, and every 15
seconds while the app is resumed. Temporary connection failures preserve the
last confirmed unread state.

Android keeps the existing `qrdify_alerts` channel so backend FCM payloads remain
compatible. New channel creation explicitly enables high importance, the device's
default notification sound, vibration, and launcher badging. Foreground pushes
use the same channel for native status-bar notifications and heads-up banners.
Background notifications continue to use the existing Firebase notification
payload. Keep its Android channel ID as `qrdify_alerts`, request high delivery
priority, and include the default sound. Existing account validation, generic
lock-screen text, duplicate suppression, and notification tap routing remain.

Android controls final presentation. Existing user channel settings, permission
denial, silent mode, and Do Not Disturb can suppress sound or banners. The app
does not override those choices. A launcher controls its own badge color; the
red dots described above are in-app indicators.

Native push still requires the matching push-enabled backend, device registration,
working Firebase credentials, and the correct Android application configuration.
Without these, the inbox and unread dots update while the app is open, but remote
background banners and sounds are unavailable. iOS push remains unconfigured.

## Release verification

Android release 1.1.6+8 uses the existing production Firebase project
`qrdify-1ed08` (sender `761958850057`), package `online.qridify.twces`, and
Firebase app `1:761958850057:android:f28ab2bea9e1cb16f422d8`. Its Android client
configuration is in the ignored `android/app/google-services.json`. The Admin
service-account JSON stays outside the mobile repository and APK.

The backend push settings must use the same project:

```dotenv
MOBILE_PUSH_ENABLED=true
MOBILE_PUSH_PROJECT_ID=qrdify-1ed08
MOBILE_PUSH_CREDENTIALS=/absolute/private/path/to/qrdify-1ed08-service-account.json
```

Keep working Google sign-in credentials in place. After changing backend
settings, clear Laravel configuration and restart its queue workers. Upgrade
phones built against `qrdify-web` and reopen the app while signed in so their
push tokens register with the production project. Existing inbox data remains
on the backend. These settings supersede the Firebase section of the original
2026-10-25 deployment bundle if using an older copy.

Run `flutter analyze`, `flutter test`, and a signed Android release build. On a
test phone, allow School alerts and test a real attendance push with the app open,
backgrounded, and terminated. Confirm a status-bar entry, heads-up banner, default
sound, correct child routing, and unread dots clearing only after successful read
operations. Also test denied permission, a muted channel, and an in-place update
from the public APK. Do not submit synthetic attendance scans to production as
part of local mobile verification.
