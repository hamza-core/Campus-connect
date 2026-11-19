namespace CampusConnect.Api.Chat;

public static class ChatEndpoints
{
    public static IServiceCollection AddChat(this IServiceCollection services, IConfiguration config, IHostEnvironment env)
    {
        services.AddSingleton(_ => KnowledgeIndex.FromDirectory(Path.Combine(AppContext.BaseDirectory, "knowledge")));
        var key = config["ANTHROPIC_API_KEY"];
        if (string.IsNullOrWhiteSpace(key)) services.AddSingleton<IChatModel, UnavailableChatModel>();
        else services.AddSingleton<IChatModel>(_ => new AnthropicChatModel(key, config["ANTHROPIC_MODEL"] is { Length: > 0 } m ? m : "claude-haiku-5-5", config.GetValue("CHAT_MAX_TOKENS", 700)));
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
