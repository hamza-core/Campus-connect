using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CampusConnect.Tests;

internal static class StatusRequests
{
    public static async Task<HttpResponseMessage> PatchStatusAsync(this HttpClient client, string path, object payload)
    {
        var body = JsonSerializer.SerializeToNode(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web))!.AsObject();
        using var response = await client.GetAsync(path[..^"/status".Length]);
        if (response.IsSuccessStatusCode)
        {
            var complaint = await response.Content.ReadFromJsonAsync<JsonObject>();
            body["rowVersion"] = complaint!["data"]!["rowVersion"]!.GetValue<string>();
        }
        else body["rowVersion"] = Guid.Empty.ToString();
        return await client.PatchAsJsonAsync(path, body);
    }
}
