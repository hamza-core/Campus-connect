using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CampusConnect.Api;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;

namespace CampusConnect.Tests;

public sealed class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public string Connection { get; } = ConnectionString();
    public string SeedPassword { get; } = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(16));
    private static string ConnectionString()
    {
        var value = Environment.GetEnvironmentVariable("TEST_DATABASE_URL") ?? "Server=(localdb)\\MSSQLLocalDB;Integrated Security=true;TrustServerCertificate=true";
        var builder = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(value) { InitialCatalog = "CampusConnect_Test_" + Guid.NewGuid().ToString("N") };
        return builder.ConnectionString;
    }
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["JWT_SECRET"] = "integration-tests-only-secret-with-at-least-32-bytes",
            ["ConnectionStrings:DefaultConnection"] = Connection,
            ["Auth:PermitLimit"] = "1000",
            ["Logging:LogLevel:Default"] = "Warning"
        }));
    }
    public async Task InitializeAsync()
    {
        using var client = CreateClient();
        await using var scope = Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDb>();
        await db.Database.MigrateAsync(); await Seed.Run(db, SeedPassword);
    }
    public new async Task DisposeAsync()
    {
        await using (var scope = Services.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<AppDb>().Database.EnsureDeletedAsync();
        await base.DisposeAsync();
    }
    public async Task<HttpClient> Login(string name)
    {
        var client = CreateClient();
        var response = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = name + "@campusconnect.edu", password = SeedPassword });
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonObject>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", body!["token"]!.GetValue<string>());
        return client;
    }
}
public class ApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task Health_and_categories_match_contract()
    {
        using var client = factory.CreateClient();
        var health = await client.GetFromJsonAsync<JsonObject>("/api/v1/health");
        Assert.Equal("ok", health!["status"]!.GetValue<string>());
        var categories = await client.GetFromJsonAsync<JsonObject>("/api/v1/meta/categories");
        Assert.Equal(4, categories!["data"]!.AsArray().Count);
    }
    [Theory]
    [InlineData("library", "demo-002")]
    [InlineData("student2", "demo-000")]
    public async Task Direct_access_outside_scope_is_403(string user, string id)
    {
        using var client = await factory.Login(user);
        var response = await client.GetAsync("/api/v1/complaints/" + id);
        await AssertError(response, HttpStatusCode.Forbidden, "FORBIDDEN");
    }
    [Fact]
    public async Task Department_admin_cannot_change_other_department_status()
    {
        using var client = await factory.Login("library");
        var response = await client.PatchStatusAsync("/api/v1/complaints/demo-002/status", new { status = "IN_PROGRESS" });
        await AssertError(response, HttpStatusCode.Forbidden, "FORBIDDEN");
    }
    [Theory]
    [InlineData("/analytics/summary")]
    [InlineData("/analytics/by-department")]
    [InlineData("/analytics/by-status")]
    [InlineData("/analytics/trend")]
    [InlineData("/analytics/recurring")]
    [InlineData("/admin/complaints/export.csv")]
    public async Task Students_cannot_use_admin_endpoints(string path)
    {
        using var client = await factory.Login("student");
        await AssertError(await client.GetAsync("/api/v1" + path), HttpStatusCode.Forbidden, "FORBIDDEN");
    }
    [Fact]
    public async Task Students_cannot_change_status_or_escalate_registration_role()
    {
        using var student = await factory.Login("student");
        await AssertError(await student.PatchStatusAsync("/api/v1/complaints/demo-000/status", new { status = "IN_PROGRESS" }), HttpStatusCode.Forbidden, "FORBIDDEN");
        using var anonymous = factory.CreateClient();
        var response = await anonymous.PostAsJsonAsync("/api/v1/auth/register", new { name = "New Student", email = Guid.NewGuid() + "@test.edu", password = "Campus@123", role = "SUPER_ADMIN", departmentId = "dept-library" });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonObject>();
        Assert.Equal("STUDENT", body!["user"]!["role"]!.GetValue<string>());
        Assert.Null(body["user"]!["department"]);
    }
    [Fact]
    public async Task List_filters_cannot_widen_scope_and_invalid_parameters_are_422()
    {
        using var client = await factory.Login("library");
        var body = await client.GetFromJsonAsync<JsonObject>("/api/v1/complaints?departmentId=dept-lab-it&pageSize=100");
        Assert.All(body!["data"]!.AsArray(), x => Assert.Equal("dept-library", x!["department"]!["id"]!.GetValue<string>()));
        await AssertError(await client.GetAsync("/api/v1/complaints?page=0"), HttpStatusCode.UnprocessableEntity, "VALIDATION_FAILED");
        await AssertError(await client.GetAsync("/api/v1/complaints?status=INVALID"), HttpStatusCode.UnprocessableEntity, "VALIDATION_FAILED");
    }
    [Fact]
    public async Task Complete_complaint_flow_routes_audits_notifies_and_accepts_feedback_once()
    {
        using var student = await factory.Login("student"); using var admin = await factory.Login("library"); using var super = await factory.Login("super");
        var created = await student.PostAsJsonAsync("/api/v1/complaints", new { category = "LIBRARY", title = "Library equipment issue", description = "The library desk equipment needs repair.", priority = "HIGH", anonymousToStaff = true, departmentId = "dept-lab-it" });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var data = (await created.Content.ReadFromJsonAsync<JsonObject>())!["data"]!;
        var id = data["id"]!.GetValue<string>();
        Assert.Equal("dept-library", data["department"]!["id"]!.GetValue<string>());
        Assert.StartsWith("CC-", data["ticket"]!.GetValue<string>());
        var view = (await admin.GetFromJsonAsync<JsonObject>("/api/v1/complaints/" + id))!["data"]!;
        Assert.Null(view["author"]);
        Assert.Equal("Anonymous student", view["timeline"]![0]!["actor"]!["name"]!.GetValue<string>());
        var superView = (await super.GetFromJsonAsync<JsonObject>("/api/v1/complaints/" + id))!["data"]!;
        Assert.NotNull(superView["author"]);
        await AssertError(await admin.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "RESOLVED", remark = "done" }), HttpStatusCode.Conflict, "INVALID_TRANSITION");
        Assert.Equal(HttpStatusCode.OK, (await admin.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "IN_PROGRESS" })).StatusCode);
        await AssertError(await admin.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "RESOLVED" }), HttpStatusCode.UnprocessableEntity, "VALIDATION_FAILED");
        Assert.Equal(HttpStatusCode.Created, (await admin.PostAsJsonAsync($"/api/v1/complaints/{id}/comments", new { body = "We are repairing the desk." })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await admin.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "RESOLVED", remark = "Equipment repaired." })).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await student.PostAsJsonAsync($"/api/v1/complaints/{id}/feedback", new { rating = 5, comment = "Thanks" })).StatusCode);
        await AssertError(await student.PostAsJsonAsync($"/api/v1/complaints/{id}/feedback", new { rating = 4 }), HttpStatusCode.Conflict, "CONFLICT");
        var detail = (await student.GetFromJsonAsync<JsonObject>($"/api/v1/complaints/{id}"))!["data"]!;
        Assert.Equal(4, detail["timeline"]!.AsArray().Count);
        var notifications = await student.GetFromJsonAsync<JsonObject>("/api/v1/notifications?unreadOnly=true");
        Assert.Contains(notifications!["data"]!.AsArray(), n => n!["complaintId"]!.GetValue<string>() == id);
        using var other = await factory.Login("student2");
        var otherNotes = await other.GetFromJsonAsync<JsonObject>("/api/v1/notifications");
        Assert.DoesNotContain(otherNotes!["data"]!.AsArray(), n => n!["complaintId"]!.GetValue<string>() == id);
        Assert.Equal(HttpStatusCode.NoContent, (await student.PostAsync("/api/v1/notifications/read-all", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await super.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "IN_PROGRESS" })).StatusCode);
    }
    [Fact]
    public async Task Auth_validation_and_missing_tokens_use_error_envelope()
    {
        using var client = factory.CreateClient();
        await AssertError(await client.GetAsync("/api/v1/auth/me"), HttpStatusCode.Unauthorized, "UNAUTHORIZED");
        await AssertError(await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "student@campusconnect.edu", password = "wrong" }), HttpStatusCode.Unauthorized, "UNAUTHORIZED");
        await AssertError(await client.PostAsJsonAsync("/api/v1/auth/register", new { name = "x", email = "bad", password = "short" }), HttpStatusCode.UnprocessableEntity, "VALIDATION_FAILED");
        await AssertError(await client.PostAsync("/api/v1/auth/login", new StringContent("{", System.Text.Encoding.UTF8, "application/json")), HttpStatusCode.UnprocessableEntity, "VALIDATION_FAILED");
    }
    [Fact]
    public async Task Analytics_are_scoped_and_seed_is_idempotent()
    {
        using var client = await factory.Login("labit");
        var rows = (await client.GetFromJsonAsync<JsonObject>("/api/v1/analytics/by-department"))!["data"]!.AsArray();
        Assert.Single(rows); Assert.Equal("dept-lab-it", rows[0]!["department"]!["id"]!.GetValue<string>());
        foreach (var path in new[] { "summary", "by-status", "trend?days=7", "recurring" })
            Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/analytics/" + path)).StatusCode);
        await using var scope = factory.Services.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<AppDb>();
        var count = await db.Complaints.CountAsync(); await Seed.Run(db, factory.SeedPassword); Assert.Equal(count, await db.Complaints.CountAsync());
    }
    [Fact]
    public async Task SignalR_requires_authentication_and_support_preserves_scope()
    {
        using var anonymous = factory.CreateClient();
        await AssertError(await anonymous.PostAsync("/hubs/notifications/negotiate?negotiateVersion=1", null), HttpStatusCode.Unauthorized, "UNAUTHORIZED");
        using var student = await factory.Login("student");
        Assert.Equal(HttpStatusCode.OK, (await student.PostAsync("/hubs/notifications/negotiate?negotiateVersion=1", null)).StatusCode);
        await AssertError(await student.PutAsync("/api/v1/complaints/demo-000/support", null), HttpStatusCode.Forbidden, "FORBIDDEN");
        await AssertError(await student.PutAsync("/api/v1/complaints/demo-001/support", null), HttpStatusCode.Forbidden, "FORBIDDEN");
    }
    private static async Task AssertError(HttpResponseMessage response, HttpStatusCode status, string code)
    {
        Assert.Equal(status, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonObject>(); Assert.Equal(code, body!["error"]!["code"]!.GetValue<string>());
    }
}
