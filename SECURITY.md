# Security and release checks

QRDify handles school records. Local automated checks do not establish production readiness or replace school approval and Android device testing.

## Current controls

- Native sessions use encrypted token storage, persisted expiry, server validation on resume, and a separate durable logout marker. Authentication failures close private screens. A required password change blocks school-record modules.
- Authenticated API requests stay on the configured HTTP(S) origin. Redirect following is disabled and response sizes are bounded. Release API configuration requires HTTPS.
- Location sharing requires consent and appropriate permissions. Stop cancels local tracking/acquisition. Notification permission and channel checks apply; device-specific visibility must be tested.
- Android backup/device-transfer exclusions cover sensitive app storage. Imported documents use bounded memory and picker-owned temporary copies are cleaned up. Signing material and build artifacts stay out of source control.
- Parent excuse workflows depend on matching backend authorization, private storage, migrations and audit records. The server owns record identifiers, recipients and status.

## Before distribution

1. Deploy and verify the matching backend contract and database migrations with synthetic accounts. Test unrelated-account access, guardian permissions, private attachments and record integrity.
2. Test on Android phones: first-login password changes, expired/revoked sessions, offline logout/restart, file upload/cache cleanup, notification permission/channel visibility, consent withdrawal, background/force-stop behavior and backup/device transfer.
3. Obtain school policy decisions for retention, medical-document access, shared-phone protection and location sharing.
4. Verify the original app's signing certificate and published version before an update. Increment the release version only as part of the coordinated release. This working-source update does not itself distribute a new APK.
5. Inspect the final signed APK and verify the actual production API configuration. Keep `USE_MOBILE_API=false` until all app modules support the complete mobile-prefixed contract.

## Local verification

```text
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Internal audit findings, operational notes and raw audit artifacts are maintained separately. Report vulnerabilities privately to the repository maintainers; do not put credentials or real school records in public issues.
