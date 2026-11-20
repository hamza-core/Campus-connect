using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using CampusConnect.Api;
using CampusConnect.Api.Vision;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace CampusConnect.Tests;

public class VisionUnitTests
{
    [Fact]
    public void Detects_image_types_by_magic_bytes_not_by_name()
    {
        byte[] jpg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        byte[] png = [0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        Assert.Equal("image/jpeg", UploadStore.Detect(jpg)!.Value.Mime);
        Assert.Equal("image/png", UploadStore.Detect(png)!.Value.Mime);
        Assert.Null(UploadStore.Detect("<html>not an image</html>"u8));
    }

    [Fact]
    public void Only_generated_ids_are_accepted()
    {
        Assert.True(UploadStore.IsId(Guid.NewGuid().ToString("N")));
        Assert.False(UploadStore.IsId("../../etc/passwd"));
        Assert.Null(UploadStore.IdFromUrl("/api/v1/uploads/../x"));
    }

    [Fact]
    public void Parse_reuses_known_labels_and_sanitizes_the_rest()
    {
        var known = new Dictionary<string, List<FrequentIssue>> { ["LAB_IT"] = [new("Internet connectivity issues", 7)] };
        var reuse = IssueAnalyzer.Parse("```json\n{\"category\":\"lab_it\",\"issue\":\"internet connectivity issues.\",\"priority\":\"high\",\"summary\":\"Router light is red\"}\n```", known);
        Assert.Equal(("LAB_IT", "Internet connectivity issues", "HIGH", false), (reuse.Category, reuse.Issue, reuse.Priority, reuse.IsNewIssue));
        var fresh = IssueAnalyzer.Parse("{\"category\":\"nonsense\",\"issue\":\"Broken\\u0007 chair\",\"priority\":\"urgent\"}", known);
        Assert.Equal(("CAFETERIA", "Broken chair", "MEDIUM", true), (fresh.Category, fresh.Issue, fresh.Priority, fresh.IsNewIssue));
        Assert.Throws<ApiError>(() => IssueAnalyzer.Parse("no json here", known));
    }
}

public class VisionEndpointTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private sealed class FakeVision : IVisionModel
    {
        public bool Available => true;
        public Task<string> Analyze(string system, string userText, byte[] image, string mime, CancellationToken ct) =>
            Task.FromResult("{\"category\":\"LAB_IT\",\"issue\":\"Projector not working\",\"priority\":\"MEDIUM\",\"summary\":\"A projector shows no signal.\"}");
    }

    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 1, 2, 3];

    private WebApplicationFactory<Program> With(IVisionModel model) => factory.WithWebHostBuilder(b =>
    {
        b.UseSetting("UPLOADS_DIR", Path.Combine(Path.GetTempPath(), "cc-uploads-" + Guid.NewGuid().ToString("N")));
        b.ConfigureServices(s => { s.RemoveAll<IVisionModel>(); s.AddSingleton(model); });
    });

    private async Task<HttpClient> Student(WebApplicationFactory<Program> app)
    {
        var client = app.CreateClient();
        var login = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "student@campusconnect.edu", password = factory.SeedPassword });
        client.DefaultRequestHeaders.Authorization = new("Bearer", (await login.Content.ReadFromJsonAsync<JsonObject>())!["token"]!.GetValue<string>());
        return client;
    }

    private static MultipartFormDataContent Form(byte[] bytes)
    {
        var form = new MultipartFormDataContent();
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        form.Add(file, "file", "photo.png");
        return form;
    }

    [Fact]
    public async Task Upload_analyze_and_attach_to_a_complaint()
    {
        using var app = With(new FakeVision());
        using var client = await Student(app);
        var up = await client.PostAsync("/api/v1/uploads", Form(Png));
        Assert.Equal(HttpStatusCode.Created, up.StatusCode);
        var data = (await up.Content.ReadFromJsonAsync<JsonObject>())!["data"]!;
        var id = data["id"]!.GetValue<string>(); var url = data["url"]!.GetValue<string>();

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync(url)).StatusCode);
        var analyze = await client.PostAsJsonAsync("/api/v1/complaints/analyze", new { imageId = id });
        Assert.Equal(HttpStatusCode.OK, analyze.StatusCode);
        var suggestion = (await analyze.Content.ReadFromJsonAsync<JsonObject>())!["data"]!;
        Assert.Equal("LAB_IT", suggestion["category"]!.GetValue<string>());
        Assert.Equal("Projector not working", suggestion["issue"]!.GetValue<string>());

        var create = await client.PostAsJsonAsync("/api/v1/complaints", new
        {
            category = "LAB_IT", title = "Projector not working", description = "The projector in lab 3 shows no signal.",
            subIssue = "Projector not working", imageUrls = new[] { url }
        });
        Assert.Equal(HttpStatusCode.Created, create.StatusCode);
        var created = (await create.Content.ReadFromJsonAsync<JsonObject>())!["data"]!;
        Assert.Equal(url, created["imageUrls"]![0]!.GetValue<string>());

        var frequent = await client.GetAsync("/api/v1/meta/frequent-issues?category=LAB_IT");
        var labels = (await frequent.Content.ReadFromJsonAsync<JsonObject>())!["data"]!.AsArray().Select(x => x!["label"]!.GetValue<string>());
        Assert.Contains("Projector not working", labels);
    }

    [Fact]
    public async Task Rejects_non_images_and_unknown_photo_references()
    {
        using var app = With(new FakeVision());
        using var client = await Student(app);
        Assert.Equal((HttpStatusCode)422, (await client.PostAsync("/api/v1/uploads", Form("<html>x</html>"u8.ToArray()))).StatusCode);
        var bad = await client.PostAsJsonAsync("/api/v1/complaints", new
        {
            category = "LAB_IT", title = "Projector broken", description = "The projector shows no signal.", imageUrls = new[] { "https://evil.example/x.png" }
        });
        Assert.Equal((HttpStatusCode)422, bad.StatusCode);
    }

    [Fact]
    public async Task Analyze_without_a_vision_key_is_503_and_needs_login()
    {
        using var app = With(new UnavailableVisionModel());
        using var client = await Student(app);
        var up = await client.PostAsync("/api/v1/uploads", Form(Png));
        var id = (await up.Content.ReadFromJsonAsync<JsonObject>())!["data"]!["id"]!.GetValue<string>();
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.PostAsJsonAsync("/api/v1/complaints/analyze", new { imageId = id })).StatusCode);
        using var anonymous = app.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.PostAsJsonAsync("/api/v1/complaints/analyze", new { imageId = id })).StatusCode);
    }
}
