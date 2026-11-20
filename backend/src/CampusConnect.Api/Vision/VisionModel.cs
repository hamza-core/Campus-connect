using System.Net.Http.Json;
using System.Text.Json.Nodes;

namespace CampusConnect.Api.Vision;

/// <summary>Seam for an image-capable model so tests and a missing key never touch the network.</summary>
public interface IVisionModel
{
    bool Available { get; }
    Task<string> Analyze(string system, string userText, byte[] image, string mime, CancellationToken ct);
}

public sealed class UnavailableVisionModel : IVisionModel
{
    public bool Available => false;
    public Task<string> Analyze(string system, string userText, byte[] image, string mime, CancellationToken ct) =>
        throw new InvalidOperationException("VISION_API_KEY is not configured.");
}

/// <summary>OpenAI-compatible vision call (Google Gemini free tier by default). Config: VISION_API_KEY, VISION_BASE_URL, VISION_MODEL.</summary>
public sealed class OpenAiCompatibleVisionModel(HttpClient http, string apiKey, string model, string? reasoningEffort = null) : IVisionModel
{
    public bool Available => true;

    public async Task<string> Analyze(string system, string userText, byte[] image, string mime, CancellationToken ct)
    {
        var dataUri = $"data:{mime};base64,{Convert.ToBase64String(image)}";
        var body = new Dictionary<string, object>
        {
            ["model"] = model,
            ["temperature"] = 0.1,
            ["messages"] = new object[]
            {
                new { role = "system", content = system },
                new { role = "user", content = new object[]
                {
                    new { type = "text", text = userText },
                    new { type = "image_url", image_url = new { url = dataUri } }
                } }
            }
        };
        if (!string.IsNullOrWhiteSpace(reasoningEffort)) body["reasoning_effort"] = reasoningEffort;
        using var response = await Chat.HttpRetry.Send(http, () =>
        {
            var request = new HttpRequestMessage(HttpMethod.Post, "chat/completions") { Content = JsonContent.Create(body) };
            request.Headers.Authorization = new("Bearer", apiKey);
            return request;
        }, ct);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonObject>(ct);
        var text = json?["choices"]?[0]?["message"]?["content"]?.GetValue<string>()?.Trim();
        return string.IsNullOrEmpty(text) ? throw new InvalidOperationException("The model returned no text.") : text;
    }
}
