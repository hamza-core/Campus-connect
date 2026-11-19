# CampusConnect backend

ASP.NET Core 10, EF Core 10, SQL Server and optional authenticated SignalR. This is the human-selected backend stack; routes remain /api/v1. No frontend/views are included. PR #3's owner review selects read-only SuperAdmin access and mandatory row versions. The integrator is revising the canonical contract separately; see contracts/PR3_REVIEW.md for the exact changes.

## Local setup (PowerShell)

Install a .NET 10 SDK and SQL Server 2022+ (or Windows LocalDB). global.json already uses latestFeature roll-forward. From backend/:

    dotnet tool restore
    dotnet restore CampusConnect.sln --locked-mode
    $env:JWT_SECRET = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
    $env:ConnectionStrings__DefaultConnection = 'Server=(localdb)\MSSQLLocalDB;Database=CampusConnect;Integrated Security=true;TrustServerCertificate=true'
    $env:CORS_ORIGINS = 'http://localhost:5173'
    $env:SEED_PASSWORD = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    dotnet run --project src/CampusConnect.Api -- --seed
    dotnet run --project src/CampusConnect.Api --no-launch-profile --urls http://localhost:4000

Integrated Security is a local Windows option only. There is no runtime connection-string fallback: ConnectionStrings__DefaultConnection is required in all environments. ASP.NET Core does not automatically load .env; export variables or configure the host. Local Docker requires SQL authentication; use sqlserver as host for its database, and TrustServerCertificate=true for the container's self-signed certificate. Set the variables before docker compose up -d. Apply migrations explicitly before accepting traffic.

No seeding occurs on normal startup. Explicit --seed requires SEED_PASSWORD (at least 8 characters and at most 72 UTF-8 bytes), including Production. Missing/invalid seed credentials fail before migrations or seed writes. Explicit reseeding rotates existing demo-account passwords too. Do not seed demo accounts into a real production database; provision real administrators/departments separately.

Demo emails: super@campusconnect.edu, cafeteria@campusconnect.edu, library@campusconnect.edu, labit@campusconnect.edu, academic@campusconnect.edu, student@campusconnect.edu, student2@campusconnect.edu. Use the externally supplied SEED_PASSWORD; there is no committed shared default.

## Authorization and concurrency

- Students submit/read their own complaints and rate resolved complaints once. Support stays denied under deferred issue #4. Students cannot post department remarks.
- Department admins read/update complaints in their department and provide remarks. Out-of-scope direct access returns 403.
- SuperAdmin is read-only: system-wide complaint reads, analytics and CSV exports. Status/comments return 403; allowedTransitions is empty. Terminal complaints cannot be reopened.
- Status PATCH requires rowVersion from a fresh complaint GET or latest successful status response. Missing/invalid version returns 422; stale version returns 409 CONFLICT with no history/notification/status writes. Comments change the version too; fetch detail afterward.
- Status/remark writes atomically save their timeline and owner notification. There is no self-notification. A ticket-counter duplicate/deadlock is retried once in a fresh serializable transaction.
- Auth attempts are limited per client IP after trusted forwarded headers. 429 uses RATE_LIMITED.

CampusConnect.http uses direct named-response references. Run the logins, createComplaint and departmentDetail first. After status/comment changes, refreshBeforeResolution supplies a new version. Its password comes from the SEED_PASSWORD process variable: launch the editor from that configured shell or use a private local HTTP environment. Response-dependent global aliases cause HTTP0012 before their source request has run and are deliberately avoided.

## S3 image uploads

Images go straight from the client to Amazon S3; the API never handles file bytes. Configure `AWS_S3_BUCKET` (no dots in the name) and `AWS_REGION`. Credentials come from the default AWS chain: on EC2 attach an **IAM instance role**; locally set `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`. The role needs `s3:PutObject` and `s3:GetObject` on `arn:aws:s3:::BUCKET/campusconnect/*`.

`POST /uploads/sign` (students only) validates `contentType` (JPEG/PNG/WebP) and optional `fileSize` (1–5242880) and returns a 5-minute presigned **PUT** URL for `campusconnect/{userId}/{guid}.{ext}`, plus `method: "PUT"`, `headers` (send `Content-Type` exactly as declared; it is part of the signature), an empty `fields` object, `publicUrl` and `maxFileSize`.

Complaint image URLs must be HTTPS on `{bucket}.s3.{region}.amazonaws.com`, under the submitting user's `campusconnect/{userId}/` prefix, with a 32-hex name and a jpg/png/webp extension. Foreign hosts or buckets, other users' folders, query strings and embedded credentials are rejected without calling S3. Before attachment the API calls `HeadObject` to verify the object exists, is 1 byte–5 MiB and that its stored content type matches the extension. Storage errors fail closed (503).

S3 cannot cap the size of a presigned PUT, so an oversize or never-attached file can exist in the bucket until you clean it up. The API refuses such files at attachment. Bucket setup: block public ACLs; allow public **read** only for `campusconnect/*` through a bucket policy (images are displayed by URL); enable CORS for `PUT` only if you add a web client (native apps are unaffected).

## EC2, Nginx and SQL Server/RDS

Install the ASP.NET Core 10 runtime on EC2 and keep SQL Server separate. Use a private environment file (chmod 600) containing JWT_SECRET (at least 32 bytes), ConnectionStrings__DefaultConnection, CORS_ORIGINS, TRUSTED_PROXIES and S3 settings (AWS_S3_BUCKET, AWS_REGION). Use SQL authentication and a trusted SQL Server certificate with Encrypt=true; TrustServerCertificate=true is a deliberate local/demo exception. Restrict database port 1433 to the EC2 security group.

Publish: dotnet publish src/CampusConnect.Api -c Release -o publish. Apply migrations once as a release step: dotnet CampusConnect.Api.dll --migrate. Then start with ASPNETCORE_URLS=http://127.0.0.1:5080. Example systemd/Nginx files are in deploy/; adapt paths/domain/certificates and validate with nginx -t before installing. Configure HTTPS for Android/browser clients.

Forwarded headers run before rate limiting. Default trusted proxies are 127.0.0.1 and ::1, one hop. TRUSTED_PROXIES must list the exact immediate proxy addresses when different. Nginx overwrites X-Forwarded-For with $remote_addr and X-Forwarded-Proto with $scheme as shown in the example. Docker requires the actual Nginx-to-container peer IP; loopback defaults deliberately do not trust bridge networks. [Microsoft proxy guidance](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-10.0).

GET /api/v1/health checks database connectivity: 200 with status ok, or 503 with status unavailable. It is a readiness probe now. Optional SignalR is at /hubs/notifications; persisted REST notifications remain authoritative and mobile clients may poll every 30 seconds. Hosting request-start logs are suppressed because browser SignalR authentication may use access_token in query strings. Production HTTPS/WebSocket/reconnect checks remain deployment work. Multiple live API instances require a backplane or managed SignalR service.

## Known session gap

The demo retains seven-day HS256 access JWTs. Refresh rotation, server-side revocation and logout invalidation are not implemented. Do not shorten JWTs to 15 minutes without the separately designed refresh flow and client/security tests. This gap is explicit rather than silently expiring demo sessions.

## Verification

    dotnet build CampusConnect.sln -c Release --no-restore
    dotnet test CampusConnect.sln -c Release --logger trx
    dotnet ef migrations has-pending-model-changes --project src/CampusConnect.Api --configuration Release
    dotnet publish src/CampusConnect.Api -c Release -o publish

Tests use isolated, randomly named SQL Server databases, apply real migrations, and delete only those test databases. Windows defaults to LocalDB; Linux uses TEST_DATABASE_URL with database-creation permissions. Test seed credentials are generated per fixture. CI uses a SQL Server 2022 service and an explicit design-time connection; no test uses a production database implicitly. Build treats warnings as errors.
