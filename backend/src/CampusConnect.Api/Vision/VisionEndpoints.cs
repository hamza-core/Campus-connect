using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace CampusConnect.Api;

public record AnalyzeRequest([property: Required, StringLength(80)] string ImageId, [property: StringLength(1000)] string? Description);

public static class VisionEndpoints
{
    public static IServiceCollection AddVision(this IServiceCollection services, IConfiguration config, IHostEnvironment env)
    {
        var dir = config["UPLOADS_DIR"] is { Length: > 0 } d ? d : Path.Combine(env.ContentRootPath, "uploads");
        services.AddSingleton(new Vision.UploadStore(dir));
        var key = config["VISION_API_KEY"];
        if (string.IsNullOrWhiteSpace(key)) services.AddSingleton<Vision.IVisionModel, Vision.UnavailableVisionModel>();
        else
        {
            var baseUrl = config["VISION_BASE_URL"] is { Length: > 0 } u ? u : "https://generativelanguage.googleapis.com/v1beta/openai";
            var model = config["VISION_MODEL"] is { Length: > 0 } m ? m : "gemini-flash-latest";
            services.AddSingleton<Vision.IVisionModel>(_ => new Vision.OpenAiCompatibleVisionModel(
                new HttpClient { BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/"), Timeout = TimeSpan.FromSeconds(int.TryParse(config["VISION_TIMEOUT_SECONDS"], out var vt) && vt is > 0 and <= 120 ? vt : 25) }, key, model, config["VISION_REASONING_EFFORT"]));
        }
        services.AddScoped<Vision.IssueAnalyzer>();
        return services;
    }

    public static IEndpointRouteBuilder MapVisionEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/v1/uploads", async (IFormFile file, Vision.UploadStore store, CurrentUser current, CancellationToken ct) =>
        {
            var user = await current.Get();
            if (file.Length is 0 or > Vision.UploadStore.MaxBytes) throw new ApiError(422, "VALIDATION_FAILED", "Photo must be 1 byte to 5 MB.");
            await using var stream = file.OpenReadStream();
            var bytes = new byte[file.Length];
            await stream.ReadExactlyAsync(bytes, ct);
            var kind = Vision.UploadStore.Detect(bytes) ?? throw new ApiError(422, "VALIDATION_FAILED", "Only JPEG, PNG or WebP photos are accepted.");
            var id = await store.Save(bytes, kind.Ext, ct);
            await store.SetOwner(id, user.Id);
            return Results.Json(new { data = new { id, url = Vision.UploadStore.UrlFor(id) } }, statusCode: 201);
        }).DisableAntiforgery().RequireAuthorization().RequireRateLimiting("chat");

        // The uploader, or anyone allowed to see the complaint the photo is attached to (same scope rules as the complaint itself).
        app.MapGet("/api/v1/uploads/{id}", async (string id, Vision.UploadStore store, CurrentUser current, AppDb db, CancellationToken ct) =>
        {
            var user = await current.Get();
            var file = store.Find(id) ?? throw new ApiError(404, "NOT_FOUND", "Photo not found.");
            if (store.Owner(id) != user.Id)
            {
                var complaintId = store.ComplaintOf(id) ?? throw ApiError.Forbidden();
                var complaint = await db.Complaints.AsNoTracking().SingleOrDefaultAsync(c => c.Id == complaintId, ct) ?? throw ApiError.Forbidden();
                Scope.Check(complaint, user);
            }
            return Results.File(file.Path, file.Mime);
        }).RequireAuthorization();

        app.MapPost("/api/v1/complaints/analyze", async (AnalyzeRequest request, Vision.IssueAnalyzer analyzer, CurrentUser current, CancellationToken ct) =>
        {
            Scope.Student(await current.Get());
            return Results.Ok(new { data = await analyzer.Analyze(request.ImageId, request.Description, ct) });
        }).AddEndpointFilter<ValidationFilter>().RequireAuthorization().RequireRateLimiting("chat");

        app.MapGet("/api/v1/meta/frequent-issues", async (string? category, Vision.IssueAnalyzer analyzer, CancellationToken ct) =>
        {
            if (category is not null && !Catalog.Categories.Any(c => c.Key == category)) throw new ApiError(422, "VALIDATION_FAILED", "Unknown category.");
            return Results.Ok(new { data = await analyzer.Frequent(category, 8, ct) });
        }).RequireAuthorization();
        return app;
    }
}
