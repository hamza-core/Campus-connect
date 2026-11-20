namespace CampusConnect.Api.Chat;

public static class ChatEndpoints
{
    public static IServiceCollection AddChat(this IServiceCollection services, IConfiguration config, IHostEnvironment env)
    {
        services.AddSingleton(_ => KnowledgeIndex.FromDirectory(Path.Combine(AppContext.BaseDirectory, "knowledge")));
        var maxTokens = config.GetValue("CHAT_MAX_TOKENS", 700);
        var llmKey = config["LLM_API_KEY"];
        var anthropicKey = config["ANTHROPIC_API_KEY"];
        if (!string.IsNullOrWhiteSpace(llmKey))
        {
            var baseUrl = config["LLM_BASE_URL"] is { Length: > 0 } u ? u : "https://api.groq.com/openai/v1";
            var llmModel = config["LLM_MODEL"] is { Length: > 0 } lm ? lm : "llama-3.1-8b-instant";
            services.AddSingleton<IChatModel>(_ => new OpenAiCompatibleChatModel(
                new HttpClient { BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/"), Timeout = TimeSpan.FromSeconds(60) }, llmKey, llmModel, maxTokens, config["LLM_REASONING_EFFORT"]));
        }
        else if (!string.IsNullOrWhiteSpace(anthropicKey))
            services.AddSingleton<IChatModel>(_ => new AnthropicChatModel(anthropicKey, config["ANTHROPIC_MODEL"] is { Length: > 0 } m ? m : "claude-haiku-5-5", maxTokens));
        else services.AddSingleton<IChatModel, UnavailableChatModel>();
        services.AddScoped<ChatService>();
        return services;
    }

    public static IEndpointRouteBuilder MapChatEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/v1/chat", async (ChatRequest request, ChatService chat, CancellationToken ct) =>
            Results.Ok(new { data = await chat.Ask(request.Message, request.History?.Select(h => new ChatHistoryItem(h.Role, h.Text)).ToList(), ct) }))
            .AddEndpointFilter<ValidationFilter>().RequireAuthorization().RequireRateLimiting("chat");
        return app;
    }
}
