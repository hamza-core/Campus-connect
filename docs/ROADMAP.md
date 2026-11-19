# Roadmap

## Done
- Contract v1.2.1, .NET 10 API on EC2/RDS behind Nginx, SignalR hub, seed data, 46+ backend tests in CI.
- Flutter app: all three roles, every backend feature except the deferred "me too" support (see `docs/REQUIREMENTS_COVERAGE.md`), realtime notifications, Android popups while minimized, auto-refresh, remembered login, CSV export, charts. 37 tests, APK built in CI.
- Backups: git tags + APKs; server copy in `~/api-stable`.

## Next (ordered by value)
1. **HTTPS**: domain + Elastic IP + `certbot --nginx`; then remove `usesCleartextTraffic` and update `API_BASE_URL`.
2. **Push to admins**: backend publishes a hub event when a complaint is created (group per department + super admin); app swaps polling for the event (keep polling as fallback). Needs a `contract/` PR first.
3. **Stable release signing + app id** (replace `com.example.project`), Firebase App Distribution or Drive for testers.
4. **Refresh-token flow** (all-or-nothing: rotation, replay revocation, single-flight client).
5. **Image storage** (S3/Cloudinary) behind a new upload endpoint; then show photos to staff.
6. **FCM push** for notifications when the app is fully closed (the foreground service covers minimized only).
7. Cleanup: remove unused packages (`lottie`, `animations`, `animated_text_kit`, `flutter_staggered_animations`, `google_fonts`, `cupertino_icons`), delete demo/test complaints (`[API TEST]`, `[REALTIME TEST]`), rotate the demo password.

## Release checklist
- [ ] `flutter analyze && flutter test` green; `backend-ci` green
- [ ] APK built by `frontend-apk.yml` for the production URL
- [ ] `GET /api/v1/health` = 200; negotiate on `/hubs/notifications` = 200
- [ ] Sign in as each role from the installed APK; Library admin → Lab complaint = 403
