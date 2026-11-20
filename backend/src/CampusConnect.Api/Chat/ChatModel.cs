using Anthropic;
using Anthropic.Models.Messages;

namespace CampusConnect.Api.Chat;

public record ChatTurn(string Role, string Text);

/// <summary>Seam for the language model so tests (and a missing API key) never touch the network.</summary>
public interface IChatModel
{
    bool Available { get; }
    Task<string> Complete(string system, IReadOnlyList<ChatTurn> turns, CancellationToken cancellationToken);
}

public sealed class UnavailableChatModel : IChatModel
{
    public bool Available => false;
    public Task<string> Complete(string system, IReadOnlyList<ChatTurn> turns, CancellationToken cancellationToken) =>
        throw new InvalidOperationException("ANTHROPIC_API_KEY is not configured.");
}

/// <summary>Claude via the official Anthropic SDK. Key: <c>ANTHROPIC_API_KEY</c>; model: <c>ANTHROPIC_MODEL</c>.</summary>
public sealed class AnthropicChatModel(string apiKey, string model, int maxTokens) : IChatModel
{
    private readonly AnthropicClient client = new() { ApiKey = apiKey };
    public bool Available => true;

    public async Task<string> Complete(string system, IReadOnlyList<ChatTurn> turns, CancellationToken cancellationToken)
    {
        var messages = turns.Select(t => t.Role == "assistant"
            ? (MessageParam)new AssistantMessageParam { Content = t.Text }
            : new UserMessageParam { Content = t.Text }).ToList();
        var response = await client.Messages.Create(new MessageCreateParams
        {
            Model = model,
            MaxTokens = maxTokens,
            System = system,
            Messages = messages,
            OutputConfig = new OutputConfig { Effort = Effort.Low },
        }, cancellationToken);
        var text = string.Concat(response.Content.Select(b => b.Value).OfType<TextBlock>().Select(b => b.Text)).Trim();
        return text.Length > 0 ? text : throw new InvalidOperationException("The model returned no text.");
    }
}

/// <summary>
/// Any OpenAI-compatible chat API (Groq, Google Gemini, OpenRouter, ...). Free-tier friendly.
/// Config: <c>LLM_API_KEY</c>, <c>LLM_BASE_URL</c> (default Groq), <c>LLM_MODEL</c>.
/// </summary>
public sealed class OpenAiCompatibleChatModel(HttpClient http, string apiKey, string model, int maxTokens, string? reasoningEffort = null) : IChatModel
{
    public bool Available => true;

    public async Task<string> Complete(string system, IReadOnlyList<ChatTurn> turns, CancellationToken cancellationToken)
    {
        var messages = new List<object> { new { role = "system", content = system } };
        messages.AddRange(turns.Select(t => (object)new { role = t.Role, content = t.Text }));
        var payload = new Dictionary<string, object> { ["model"] = model, ["messages"] = messages, ["max_tokens"] = maxTokens, ["temperature"] = 0.2 };
        if (!string.IsNullOrWhiteSpace(reasoningEffort)) payload["reasoning_effort"] = reasoningEffort;
        using var response = await HttpRetry.Send(http, () =>
        {
            var request = new HttpRequestMessage(HttpMethod.Post, "chat/completions") { Content = System.Net.Http.Json.JsonContent.Create(payload) };
            request.Headers.Authorization = new("Bearer", apiKey);
            return request;
        }, cancellationToken);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.Nodes.JsonObject>(cancellationToken);
        var text = json?["choices"]?[0]?["message"]?["content"]?.GetValue<string>()?.Trim();
        return string.IsNullOrEmpty(text) ? throw new InvalidOperationException("The model returned no text.") : text;
    }
}
