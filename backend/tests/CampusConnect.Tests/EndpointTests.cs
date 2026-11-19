using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace CampusConnect.Tests;
public class EndpointTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    [Theory]
    [InlineData("image/jpeg")]
    [InlineData("image/png")]
    [InlineData("image/webp")]
    public async Task Upload_signing_returns_verifiable_Cloudinary_fields(string contentType)
    {
        using var student = await factory.Login("student");
        var response = await student.PostAsJsonAsync("/api/v1/uploads/sign", new { contentType });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var data = (await response.Content.ReadFromJsonAsync<JsonObject>())!["data"]!;
        Assert.Equal("https://api.cloudinary.com/v1_1/test-cloud/image/upload", data["uploadUrl"]!.GetValue<string>());
        var fields = data["fields"]!; var id = fields["public_id"]!.GetValue<string>(); var timestamp = fields["timestamp"]!.GetValue<string>();
        Assert.StartsWith("campusconnect/user-student/", id);
        Assert.Equal(contentType == "image/jpeg" ? "jpg" : contentType[6..], fields["allowed_formats"]!.GetValue<string>());
        Assert.Equal(5242880, data["maxFileSize"]!.GetValue<int>());
        Assert.Equal("test-public-key", fields["api_key"]!.GetValue<string>());
        Assert.Equal("false", fields["overwrite"]!.GetValue<string>());
        var expected = Convert.ToHexStringLower(SHA1.HashData(Encoding.UTF8.GetBytes($"allowed_formats={fields["allowed_formats"]!.GetValue<string>()}&overwrite=false&public_id={id}&timestamp={timestamp}test-signing-secret")));
        Assert.Equal(expected, fields["signature"]!.GetValue<string>());
        Assert.Equal($"https://res.cloudinary.com/test-cloud/image/upload/{id}", data["publicUrl"]!.GetValue<string>());
        Assert.DoesNotContain("test-signing-secret", data.ToJsonString());
    }
    [Fact]
    public async Task Upload_signing_rejects_invalid_formats_and_administrators()
    {
        using var student = await factory.Login("student"); using var admin = await factory.Login("library");
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await student.PostAsJsonAsync("/api/v1/uploads/sign", new { contentType = "application/pdf" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await admin.PostAsJsonAsync("/api/v1/uploads/sign", new { contentType = "image/jpeg" })).StatusCode);
    }
    [Fact]
    public async Task Unconfigured_uploads_return_sanitized_error()
    {
        using var unconfigured = factory.WithWebHostBuilder(b => b.ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["CLOUDINARY_CLOUD_NAME"] = "", ["CLOUDINARY_API_KEY"] = "", ["CLOUDINARY_API_SECRET"] = ""
        })));
        using var client = unconfigured.CreateClient();
        using var authenticated = await factory.Login("student"); client.DefaultRequestHeaders.Authorization = authenticated.DefaultRequestHeaders.Authorization;
        var response = await client.PostAsJsonAsync("/api/v1/uploads/sign", new { contentType = "image/jpeg" });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("INTERNAL", (await response.Content.ReadFromJsonAsync<JsonObject>())!["error"]!["code"]!.GetValue<string>());
    }
    [Fact]
    public async Task Csv_export_honours_filters_scope_and_escapes_spreadsheet_formulas()
    {
        using var student = await factory.Login("student"); using var library = await factory.Login("library"); using var lab = await factory.Login("labit");
        var marker = Guid.NewGuid().ToString("N");
        var response = await student.PostAsJsonAsync("/api/v1/complaints", new { category = "LIBRARY", title = "=HYPERLINK(\"http://example.test\")", description = "Export check " + marker, priority = "HIGH" });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var id = (await response.Content.ReadFromJsonAsync<JsonObject>())!["data"]!["id"]!.GetValue<string>();
        var query = $"?q={marker}&category=LIBRARY&status=PENDING&priority=HIGH&overdue=false&sort=priority&pageSize=1";
        var list = (await library.GetFromJsonAsync<JsonObject>("/api/v1/complaints" + query))!;
        Assert.Equal(1, list["total"]!.GetValue<int>()); Assert.Equal(id, list["data"]![0]!["id"]!.GetValue<string>());
        var csvResponse = await library.GetAsync("/api/v1/admin/complaints/export.csv" + query);
        Assert.Equal(HttpStatusCode.OK, csvResponse.StatusCode); Assert.Equal("text/csv", csvResponse.Content.Headers.ContentType!.MediaType);
        Assert.Equal("complaints.csv", csvResponse.Content.Headers.ContentDisposition!.FileName);
        var csv = await csvResponse.Content.ReadAsStringAsync();
        Assert.Contains("\"'=HYPERLINK(\"\"http://example.test\"\")\"", csv);
        var labCsv = await lab.GetStringAsync("/api/v1/admin/complaints/export.csv" + query);
        Assert.DoesNotContain("HYPERLINK", labCsv);
    }
    [Fact]
    public async Task Support_methods_preserve_scope_for_own_other_and_missing_complaints()
    {
        using var student = await factory.Login("student");
        foreach (var method in new[] { HttpMethod.Put, HttpMethod.Delete })
        foreach (var id in new[] { "demo-000", "demo-001", "missing-complaint" })
        {
            using var request = new HttpRequestMessage(method, $"/api/v1/complaints/{id}/support");
            var response = await student.SendAsync(request);
            Assert.Equal(id == "missing-complaint" ? HttpStatusCode.NotFound : HttpStatusCode.Forbidden, response.StatusCode);
        }
    }
    [Fact]
    public async Task Rejection_is_terminal_and_super_admin_cannot_reopen()
    {
        using var student = await factory.Login("student"); using var admin = await factory.Login("library"); using var super = await factory.Login("super");
        var created = await student.PostAsJsonAsync("/api/v1/complaints", new { category = "LIBRARY", title = "Rejected complaint example", description = "Test the reason and reopen restrictions." });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var id = (await created.Content.ReadFromJsonAsync<JsonObject>())!["data"]!["id"]!.GetValue<string>();
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await admin.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "REJECTED", remark = " " })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await admin.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "REJECTED", remark = "Duplicate report." })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await admin.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "IN_PROGRESS" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await super.PatchStatusAsync($"/api/v1/complaints/{id}/status", new { status = "IN_PROGRESS" })).StatusCode);
    }
    [Fact]
    public async Task Read_all_changes_only_the_callers_notifications()
    {
        using var student = await factory.Login("student"); using var other = await factory.Login("student2"); using var admin = await factory.Login("library");
        var ids = new List<string>();
        foreach (var client in new[] { student, other })
        {
            var created = await client.PostAsJsonAsync("/api/v1/complaints", new { category = "LIBRARY", title = "Notification isolation test", description = "Only the complaint owner should receive this remark." });
            Assert.Equal(HttpStatusCode.Created, created.StatusCode);
            var id = (await created.Content.ReadFromJsonAsync<JsonObject>())!["data"]!["id"]!.GetValue<string>(); ids.Add(id);
            Assert.Equal(HttpStatusCode.Created, (await admin.PostAsJsonAsync($"/api/v1/complaints/{id}/comments", new { body = "An administrator has replied." })).StatusCode);
        }
        Assert.Equal(HttpStatusCode.NoContent, (await student.PostAsync("/api/v1/notifications/read-all", null)).StatusCode);
        var own = (await student.GetFromJsonAsync<JsonObject>("/api/v1/notifications?unreadOnly=true"))!;
        Assert.Equal(0, own["unreadCount"]!.GetValue<int>()); Assert.Empty(own["data"]!.AsArray());
        var others = (await other.GetFromJsonAsync<JsonObject>("/api/v1/notifications?unreadOnly=true"))!;
        Assert.Contains(others["data"]!.AsArray(), n => n!["complaintId"]!.GetValue<string>() == ids[1]);
        Assert.DoesNotContain(others["data"]!.AsArray(), n => n!["complaintId"]!.GetValue<string>() == ids[0]);
    }
}
