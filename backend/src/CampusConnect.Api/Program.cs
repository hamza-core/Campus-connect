using System.Text;
using System.Net;
using Microsoft.AspNetCore.HttpOverrides;
using System.Threading.RateLimiting;
using CampusConnect.Api;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);
string SigningSecret()
{
    var value = builder.Configuration["JWT_SECRET"];
    if (string.IsNullOrWhiteSpace(value) || Encoding.UTF8.GetByteCount(value) < 32)
        throw new InvalidOperationException("JWT_SECRET must contain at least 32 bytes. Use environment variables or user secrets.");
    return value;
}
builder.Services.AddSingleton(_ => new JwtSettings(SigningSecret()));
builder.Services.AddDbContext<AppDb>(o => o.UseSqlServer(DatabaseConfiguration.RequireConnection(builder.Configuration)));
builder.Services.AddSingleton<IObjectStore, S3ObjectStore>();
builder.Services.AddScoped<S3Uploads>();
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.ForwardLimit = 1;
    o.KnownIPNetworks.Clear();
    o.KnownProxies.Clear();
    // Only explicit proxies are trusted; never clear these lists to trust arbitrary callers.
    var proxies = (builder.Configuration["TRUSTED_PROXIES"] ?? "127.0.0.1,::1").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
    if (proxies.Length == 0) throw new InvalidOperationException("TRUSTED_PROXIES requires at least one trusted proxy IP.");
    foreach (var address in proxies)
    {
        if (!IPAddress.TryParse(address, out var ip)) throw new InvalidOperationException("TRUSTED_PROXIES contains an invalid IP address.");
        o.KnownProxies.Add(ip);
    }
});
builder.Services.AddScoped<CurrentUser>();
builder.Services.AddScoped<ComplaintService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSignalR();
builder.Logging.AddFilter("Microsoft.AspNetCore.Hosting.Diagnostics", LogLevel.Warning);
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    var secret = SigningSecret();
    o.MapInboundClaims = false;
    o.TokenValidationParameters = new()
    {
        ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
        ValidateIssuer = true, ValidIssuer = "CampusConnect", ValidateAudience = true, ValidAudience = "CampusConnect",
        ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(30), NameClaimType = "sub", RoleClaimType = "role"
    };
    o.Events = new JwtBearerEvents
    {
        OnMessageReceived = c =>
        {
            if (c.Request.Path.StartsWithSegments("/hubs/notifications") && c.Request.Query.TryGetValue("access_token", out var token)) c.Token = token;
            return Task.CompletedTask;
        },
        OnChallenge = async c =>
        {
            c.HandleResponse(); c.Response.StatusCode = 401;
            await c.Response.WriteAsJsonAsync(new { error = new { code = "UNAUTHORIZED", message = "A valid bearer token is required." } });
        },
        OnForbidden = async c =>
        {
            c.Response.StatusCode = 403;
            await c.Response.WriteAsJsonAsync(new { error = new { code = "FORBIDDEN", message = "You do not have access to this resource." } });
        }
    };
});
builder.Services.AddAuthorization();
builder.Services.AddHttpContextAccessor();
builder.Services.Configure<RouteHandlerOptions>(o => o.ThrowOnBadRequest = true);
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
{
    var origins = (builder.Configuration["CORS_ORIGINS"] ?? "http://localhost:5173").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
    if (origins.Contains("*")) throw new InvalidOperationException("CORS_ORIGINS must contain explicit origins.");
    p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod().AllowCredentials();
}));
builder.Services.AddRateLimiter(o =>
{
    o.AddPolicy("auth", c => RateLimitPartition.GetFixedWindowLimiter(c.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = builder.Configuration.GetValue("Auth:PermitLimit", 20), Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    o.OnRejected = async (c, ct) =>
    {
        c.HttpContext.Response.StatusCode = 429;
        await c.HttpContext.Response.WriteAsJsonAsync(new { error = new { code = "RATE_LIMITED", message = "Too many attempts. Try again shortly." } }, ct);
    };
});
var app = builder.Build();
_ = app.Services.GetRequiredService<JwtSettings>();
_ = DatabaseConfiguration.RequireConnection(app.Configuration);
app.UseForwardedHeaders();
app.Use(async (c, next) =>
{
    c.Response.Headers.XContentTypeOptions = "nosniff";
    c.Response.Headers.XFrameOptions = "DENY";
    c.Response.Headers["Referrer-Policy"] = "no-referrer";
    try { await next(); }
    catch (Exception e) when (!c.Response.HasStarted)
    {
        var error = e switch
        {
            ApiError a => a,
            BadHttpRequestException => ApiError.Invalid("Malformed request body or parameters."),
            DbUpdateConcurrencyException => new ApiError(409, "CONFLICT", "The resource changed. Refresh and try again."),
            DbUpdateException => new ApiError(409, "CONFLICT", "The operation conflicts with an existing record."),
            _ when DatabaseConflicts.IsRace(e) => new ApiError(409, "CONFLICT", "A concurrent operation conflicted. Retry the request."),
            _ => new ApiError(500, "INTERNAL", "An unexpected error occurred.")
        };
        if (error.Status == 500) app.Logger.LogError(e, "Request failed: {Path}", c.Request.Path);
        c.Response.StatusCode = error.Status;
        await c.Response.WriteAsJsonAsync(new { error = new { code = error.Code, message = error.Message, fields = error.Fields } });
    }
});
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/api/v1/health", async (AppDb db, CancellationToken cancellationToken) =>
{
    var connected = await db.Database.CanConnectAsync(cancellationToken);
    return Results.Json(new { status = connected ? "ok" : "unavailable" }, statusCode: connected ? 200 : 503);
});
app.MapGet("/api/v1/meta/categories", async (AppDb db) =>
{
    var departments = await db.Departments.AsNoTracking().ToListAsync();
    return Results.Ok(new { data = Catalog.Categories.Select(x => new { key = x.Key, label = x.Label, description = x.Label + " complaints and feedback", subIssues = x.Issues,
        department = departments.Where(d => d.Slug == x.Slug).Select(Views.Department).Single() }) });
});
var auth = app.MapGroup("/api/v1/auth").AddEndpointFilter<ValidationFilter>();
auth.MapPost("/register", async (RegisterRequest request, AuthService service) => Results.Json(await service.Register(request), statusCode: 201)).RequireRateLimiting("auth");
auth.MapPost("/login", async (LoginRequest request, AuthService service) => Results.Ok(await service.Login(request))).RequireRateLimiting("auth");
auth.MapGet("/me", async (CurrentUser user) => Results.Ok(new { data = Views.User(await user.Get()) })).RequireAuthorization();
app.MapComplaintEndpoints();
app.MapAnalyticsEndpoints();
app.MapHub<NotificationHub>("/hubs/notifications").RequireAuthorization();
if (args.Contains("--migrate") || args.Contains("--seed"))
{
    await using var scope = app.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDb>();
    var seedPassword = args.Contains("--seed") ? Seed.RequirePassword(app.Configuration) : null;
    await db.Database.MigrateAsync();
    if (seedPassword is not null) await Seed.Run(db, seedPassword);
    return;
}
await app.RunAsync();
public partial class Program;
