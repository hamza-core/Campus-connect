# contract: resolve student privacy versus complaint support permissions

GitHub delivery attempted on 2026-11-19 at the user's request. The connected integration returned HTTP 403 `Resource not accessible by integration`; GitHub CLI has no authenticated hosts. **This issue has not been created remotely.**

@hamza-core

`CONTRACT.md` and `AGENTS.md` require students to access only their own complaints and require 403 on direct access to another student's complaint. The OpenAPI support routes prohibit supporting one's own complaint. This leaves no permitted target for a student's support request.

Affected operations:

- `PUT /api/v1/complaints/{id}/support`
- `DELETE /api/v1/complaints/{id}/support`

The current implementation preserves complaint privacy. Existing own/other-student targets return 403; nonexistent targets return 404. Both methods have runnable examples in `backend/CampusConnect.http` and integration tests for those responses.

Decision needed: explicitly defer support, or define narrow support/discovery permissions independently of complaint detail access. Specify eligibility, anonymity, idempotent add/remove behavior, and error statuses. Record the decision through the contract change process before enabling support. The human requested raising this issue, without selecting a new authorization policy.

To file once GitHub CLI is authenticated, run from the repository root:

```powershell
gh issue create --repo hamza-core/Campus-connect --title 'contract: resolve student privacy versus complaint support permissions' --body-file backend/issues/support-contract.md
```
