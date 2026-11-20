namespace CampusConnect.Api.Chat;

/// <summary>Free-tier AI APIs return 429/503 in bursts: retry once after a short pause.</summary>
public static class HttpRetry
{
    public static async Task<HttpResponseMessage> Send(HttpClient http, Func<HttpRequestMessage> build, CancellationToken ct)
    {
        var response = await http.SendAsync(build(), ct);
        if ((int)response.StatusCode is 429 or 503 or 502 or 504)
        {
            response.Dispose();
            await Task.Delay(TimeSpan.FromSeconds(2), ct);
            response = await http.SendAsync(build(), ct);
        }
        return response;
    }
}
