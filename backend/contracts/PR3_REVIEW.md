# PR #3 contract reconciliation

The owner selected these policies in the PR review. Existing /api/v1 paths and opaque IDs stay unchanged. The integrator owns the corresponding canonical-contract revision (PR #2); this backend PR does not silently rewrite contract/openapi.yaml.

Required canonical changes before coordinated release:

- Complaint responses include rowVersion as a UUID string. UpdateStatusRequest requires rowVersion; missing/invalid -> 422 and stale -> 409 CONFLICT.
- Status changes and comments require DEPT_ADMIN, scoped to the department. SUPER_ADMIN is read-only, has no transitions and cannot reopen; students cannot post department remarks. Historical STUDENT_REPLY values may remain readable.
- Add RATE_LIMITED to Error.code and document 429 for auth endpoints.
- Health adds 503 with status unavailable when SQL is unreachable; 200 status ok is unchanged.
- Upload signing accepts optional integer fileSize from 1 to 5242880 and returns additive maxFileSize=5242880. Signed fields include allowed_formats. Complaint images must come from the configured Cloudinary cloud and submitting user's assigned folder and pass server-side metadata/size verification.
- Demo credentials are supplied through SEED_PASSWORD; remove the root documentation's shared-password promise. No runtime Windows/localhost connection fallback remains.
- Support stays deferred and denied. SignalR remains optional; REST is authoritative. JWT lifetime remains seven days until the separate refresh-token increment.

Compatibility impact: requiring rowVersion and removing SuperAdmin/student writes are intentional owner-selected breaking policy changes. Update clients and root contract together before deployment. Current HTTP examples and integration tests follow these policies. SDK latestFeature roll-forward was already present, so no change was needed.
