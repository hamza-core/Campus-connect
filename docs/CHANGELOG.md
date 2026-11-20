# Contract Changelog

## 1.2.1 — documentation only (no wire changes)
- `CONTRACT.md` §4a documents the SignalR hub (`/hubs/notifications`, `access_token` query, `notification` event payload) and §4b the client behaviour the backend can rely on (rowVersion, 10 s polling, rate limits).
- OpenAPI `info.description` points to the hub. The Flutter app now consumes every endpoint except the deferred support routes.

## 1.2.0 — image upload removed (owner decision: no storage provider for now)
**Breaking:** `POST /uploads/sign` is removed. `imageUrls` on `POST /complaints` is deprecated: accepted but ignored; responses always return `imageUrls: []`. The mobile app keeps attached images on the device and does not send them. A storage provider (S3/Cloudinary) can be added later via a `contract/` PR.

## 1.1.0 — aligns the spec with the implemented backend (PR #3, `backend/contracts/PR3_REVIEW.md`)
**Breaking vs 1.0.0**
- `PATCH /complaints/{id}/status` requires `rowVersion` (UUID); missing → 422, stale → 409
- Status changes and `POST /complaints/{id}/comments` are **DEPT_ADMIN only**; SUPER_ADMIN is read-only (no reopen); students cannot post remarks
- `Complaint.rowVersion` added (required in responses)

**Additive**
- Error code `RATE_LIMITED` and 429 on login/register
- `GET /health` may return 503 `{ status: "unavailable" }`
- (`/uploads/sign` was briefly specified here; it was removed again in 1.2.0.)
- Support endpoints marked `deprecated` (deferred, always 403 — issue #4)
- Production server entry (`http://13.53.165.254/api/v1`)

Stack and hosting are documented in `docs/ARCHITECTURE.md` (.NET 10 / SQL Server / AWS).

## 1.0.0
Initial contract.

## 1.3.0 — AI assistant
- Added `POST /chat` (retrieval-augmented assistant, additive). See `docs/CHATBOT.md`.

## 1.4.0 — Photos and AI issue detection
- Added `POST /uploads`, `GET /uploads/{id}`, `POST /complaints/analyze`, `GET /meta/frequent-issues`; `POST /complaints` now stores up to 3 validated `imageUrls` (previously ignored).

## 1.5.0 — Photo visibility and chat for every role
- `GET /uploads/{id}` is scoped (uploader or anyone allowed to see the complaint). Uploads can only be attached by their uploader. `/chat` is role-aware: staff-only notes are hidden from students.

## 1.6.0 — Year filter and related complaints
- `GET /complaints` accepts `year` (and `month`); added `GET /complaints/{id}/related`.
