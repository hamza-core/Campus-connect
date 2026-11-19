# PR #3 review fixes — local validation

Implemented on isolated branch be/pr3-fixes from PR head 52b590c. The shared be/extra-features checkout is untouched.

- Locked restore: passed.
- Release compilation with warnings treated as errors: passed.
- Full SQL Server LocalDB unit/integration/OpenAPI suite: 63 passed, 0 failed (TestResults/pr3-review.trx).
- EF model/migration check: no pending model changes; no new schema migration required.
- Release publish: passed.
- GitHub CI and deployment are separate checks; no production smoke-test claim is made here.

Resolved review changes: trusted single-hop forwarded headers before rate limiting; required database configuration; required rowVersion with stale-write rejection; external seed password and explicit rotation; account-scoped Cloudinary URL and real-resource verification; no self-notification; RATE_LIMITED; database readiness; one ticket-race retry; CSV control-character neutralization; read-only SuperAdmin/department-only remarks; JWT gap documented. SDK latestFeature roll-forward was already present.

Cloudinary's documented API has no signed max_file_size parameter. Format restrictions are signed, declared oversize uploads are rejected, and real asset bytes/format are verified before attachment. A strict cap before Cloudinary stores a direct upload is not implemented or claimed; see README's provider references.

Canonical contract revision remains integrator-owned; required deltas are in contracts/PR3_REVIEW.md. Support stays deferred/denied, SignalR optional, Cloudinary retained. No frontend/views or optional extra-feature code is included.
