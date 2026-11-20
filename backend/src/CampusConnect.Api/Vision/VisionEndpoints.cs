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
                new HttpClient { BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/"), Timeout = TimeSpan.FromSeconds(45) }, key, model));
        }
        services.AddScoped<Vision.IssueAnalyzer>();
        return services;
    }

    public static IEndpointRouteBuilder MapVisionEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/v1/uploads", async (IFormFile file, Vision.UploadStore store, CancellationToken ct) =>
        {
            if (file.Length is 0 or > Vision.UploadStore.MaxBytes) throw new ApiError(422, "VALIDATION_FAILED", "Photo must be 1 byte to 5 MB.");
            await using var stream = file.OpenReadStream();
            var bytes = new byte[file.Length];
            await stream.ReadExactlyAsync(bytes, ct);
            var kind = Vision.UploadStore.Detect(bytes) ?? throw new ApiError(422, "VALIDATION_FAILED", "Only JPEG, PNG or WebP photos are accepted.");
            var id = await store.Save(bytes, kind.Ext, ct);
            return Results.Json(new { data = new { id, url = Vision.UploadStore.UrlFor(id) } }, statusCode: 201);
        }).DisableAntiforgery().RequireAuthorization().RequireRateLimiting("chat");

        app.MapGet("/api/v1/uploads/{id}", (string id, Vision.UploadStore store) =>
            store.Find(id) is { } f ? Results.File(f.Path, f.Mime) : Results.Json(new { error = new { code = "NOT_FOUND", message = "Photo not found." } }, statusCode: 404))
            .RequireAuthorization();

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
