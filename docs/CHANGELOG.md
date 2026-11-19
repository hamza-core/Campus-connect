# Contract Changelog

## 1.1.0 — aligns the spec with the implemented backend (PR #3, `backend/contracts/PR3_REVIEW.md`)
**Breaking vs 1.0.0**
- `PATCH /complaints/{id}/status` requires `rowVersion` (UUID); missing → 422, stale → 409
- Status changes and `POST /complaints/{id}/comments` are **DEPT_ADMIN only**; SUPER_ADMIN is read-only (no reopen); students cannot post remarks
- `Complaint.rowVersion` added (required in responses)

**Additive**
- Error code `RATE_LIMITED` and 429 on login/register
- `GET /health` may return 503 `{ status: "unavailable" }`
- `/uploads/sign` now returns an **Amazon S3 presigned PUT** (replaces Cloudinary): response `{ uploadUrl, method: "PUT", headers, fields: {}, publicUrl, maxFileSize }`, optional request `fileSize`; `imageUrls` must be the submitting user's own S3 objects (verified with HeadObject). Clients upload with PUT + the returned headers instead of multipart
- Support endpoints marked `deprecated` (deferred, always 403 — issue #4)
- Production server entry (`http://13.53.165.254/api/v1`)

Stack and hosting are documented in `docs/ARCHITECTURE.md` (.NET 10 / SQL Server / AWS).

## 1.0.0
Initial contract.
