using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CampusConnect.Api;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CampusConnect.Tests;

public class ReviewFixTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private static async Task<string> Create(HttpClient client)
    {
        var response = await client.PostAsJsonAsync("/api/v1/complaints", new { category = "LIBRARY", title = "PR review regression", description = "Review regression complaint details." });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<JsonObject>())!["data"]!["id"]!.GetValue<string>();
    }
    [Fact]
    public async Task Status_requires_version_rejects_stale_updates_and_super_admin_is_read_only()
    {
        using var student = await factory.Login("student"); using var admin = await factory.Login("library"); using var super = await factory.Login("super");
        var id = await Create(student); var path = $"/api/v1/complaints/{id}";
        var old = (await admin.GetFromJsonAsync<JsonObject>(path))!["data"]!["rowVersion"]!.GetValue<string>();
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await admin.PatchAsJsonAsync(path + "/status", new { status = "IN_PROGRESS" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await admin.PatchAsJsonAsync(path + "/status", new { status = "IN_PROGRESS", rowVersion = old })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await admin.PatchAsJsonAsync(path + "/status", new { status = "RESOLVED", remark = "Stale screen", rowVersion = old })).StatusCode);
        foreach (var client in new[] { super, student })
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PatchAsJsonAsync(path + "/status", new { status = "RESOLVED", remark = "No access", rowVersion = old })).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await client.PostAsJsonAsync(path + "/comments", new { body = "No write permission" })).StatusCode);
        }
        var detail = (await super.GetFromJsonAsync<JsonObject>(path))!["data"]!;
        Assert.Empty(detail["allowedTransitions"]!.AsArray()); Assert.Equal(2, detail["timeline"]!.AsArray().Count);
        Assert.Equal("IN_PROGRESS", detail["status"]!.GetValue<string>());
        await using var scope = factory.Services.CreateAsyncScope();
        Assert.Equal(1, await scope.ServiceProvider.GetRequiredService<AppDb>().Notifications.CountAsync(n => n.ComplaintId == id));
    }
    [Fact]
    public async Task First_year_concurrent_tickets_both_succeed_with_unique_sequences()
    {
        using var app = factory.WithWebHostBuilder(b => b.ConfigureServices(s => s.AddSingleton<TimeProvider>(new FixedClock())));
        using var student = await factory.Login("student");
        using var first = app.CreateClient(); using var second = app.CreateClient();
        first.DefaultRequestHeaders.Authorization = student.DefaultRequestHeaders.Authorization;
        second.DefaultRequestHeaders.Authorization = student.DefaultRequestHeaders.Authorization;
        var ids = await Task.WhenAll(Create(first), Create(second));
        Assert.NotEqual(ids[0], ids[1]);
        await using var scope = factory.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDb>();
        var tickets = await db.Complaints.Where(c => ids.Contains(c.Id)).Select(c => c.Ticket).Order().ToListAsync();
        Assert.Equal(new[] { "CC-2037-0001", "CC-2037-0002" }, tickets);
    }
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Proxy_headers_only_partition_rate_limits_when_remote_proxy_is_trusted(bool trusted)
    {
        using var app = factory.WithWebHostBuilder(b =>
        {
            b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> { ["Auth:PermitLimit"] = "1" }));
            b.ConfigureServices(s => s.AddSingleton<IStartupFilter>(new RemoteAddressFilter(trusted ? IPAddress.Loopback : IPAddress.Parse("203.0.113.20"))));
        });
        using var client = app.CreateClient();
        async Task<HttpResponseMessage> Login(string address)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/auth/login");
            request.Headers.Add("X-Forwarded-For", address); request.Headers.Add("X-Forwarded-Proto", "https");
            request.Content = JsonContent.Create(new { email = "nobody@example.test", password = "wrong" });
            return await client.SendAsync(request);
        }
        using var first = await Login("198.51.100.1"); using var repeated = await Login("198.51.100.1"); using var different = await Login("198.51.100.2");
        Assert.Equal(HttpStatusCode.Unauthorized, first.StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, repeated.StatusCode);
        Assert.Equal(trusted ? HttpStatusCode.Unauthorized : HttpStatusCode.TooManyRequests, different.StatusCode);
        Assert.Equal(trusted ? "https" : "http", first.Headers.GetValues("X-Test-Scheme").Single());
        Assert.Equal("RATE_LIMITED", (await repeated.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }
    [Fact]
    public async Task Health_reports_database_outage_and_missing_connection_fails_startup()
    {
        using var missing = factory.WithWebHostBuilder(b => b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:DefaultConnection"] = "" })));
        Assert.Throws<InvalidOperationException>(() => missing.CreateClient());
        using var outage = factory.WithWebHostBuilder(b => b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?>
        { ["ConnectionStrings:DefaultConnection"] = "Server=127.0.0.1,1;Database=Unavailable;User Id=unused;Password=unused;Encrypt=true;TrustServerCertificate=true;Connect Timeout=1;ConnectRetryCount=0" })));
        using var client = outage.CreateClient(); var response = await client.GetAsync("/api/v1/health");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("unavailable", (await response.Content.ReadFromJsonAsync<JsonObject>())!["status"]!.GetValue<string>());
    }
    [Fact]
    public void Demo_seed_requires_an_external_password()
    {
        Assert.Throws<InvalidOperationException>(() => Seed.RequirePassword(new ConfigurationBuilder().Build()));
        Assert.Throws<InvalidOperationException>(() => Seed.RequirePassword(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { ["SEED_PASSWORD"] = "short" }).Build()));
    }
    [Theory]
    [InlineData("\tPlain text")]
    [InlineData("\rPlain text")]
    [InlineData("\t=1+1")]
    public async Task Csv_neutralizes_leading_control_characters(string title)
    {
        using var student = await factory.Login("student"); using var admin = await factory.Login("library");
        var id = await Create(student);
        await using var scope = factory.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDb>();
        await db.Complaints.Where(c => c.Id == id).ExecuteUpdateAsync(s => s.SetProperty(c => c.Title, title));
        var csv = await admin.GetStringAsync("/api/v1/admin/complaints/export.csv");
        Assert.Contains("\"'" + title, csv);
    }
    [Fact]
    public async Task Explicit_reseeding_rotates_existing_demo_credentials()
    {
        await using var scope = factory.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDb>();
        var rotated = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(16));
        try
        {
            await Seed.Run(db, rotated);
            using var client = factory.CreateClient();
            Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "student@campusconnect.edu", password = factory.SeedPassword })).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "student@campusconnect.edu", password = rotated })).StatusCode);
        }
        finally { await Seed.Run(db, factory.SeedPassword); }
    }
    [Fact]
    public async Task Complaint_api_rejects_image_urls_that_are_not_server_uploads()
    {
        using var student = await factory.Login("student");
        var response = await student.PostAsJsonAsync("/api/v1/complaints", new { category = "LIBRARY", title = "Image urls rejected", description = "Foreign image URLs are not accepted.", imageUrls = new[] { "https://evil.example/image.jpg" } });
        Assert.Equal((HttpStatusCode)422, response.StatusCode);
    }
    private sealed class FixedClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(2037, 1, 1, 0, 0, 0, TimeSpan.Zero);
    }
    private sealed class RemoteAddressFilter(IPAddress address) : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use(async (context, nextMiddleware) =>
            {
                context.Connection.RemoteIpAddress = address;
                context.Response.OnStarting(() => { context.Response.Headers["X-Test-Scheme"] = context.Request.Scheme; return Task.CompletedTask; });
                await nextMiddleware();
            });
            next(app);
        };
    }
}
