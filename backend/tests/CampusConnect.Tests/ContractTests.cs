using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using CampusConnect.Api;
using Json.Schema;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.Routing.Patterns;
using Microsoft.Extensions.DependencyInjection;
using YamlDotNet.Serialization;

namespace CampusConnect.Tests;
public class ContractTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private static readonly JsonNode Contract = JsonNode.Parse(JsonSerializer.Serialize(new DeserializerBuilder()
        .WithAttemptingUnquotedStringTypeDeserialization().Build().Deserialize<object>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "openapi.yaml")))))!;

    [Fact]
    public void Every_OpenAPI_operation_has_a_registered_endpoint()
    {
        using var client = factory.CreateClient();
        var endpoints = factory.Services.GetRequiredService<EndpointDataSource>().Endpoints.OfType<RouteEndpoint>().ToList();
        foreach (var path in Contract["paths"]!.AsObject())
        foreach (var operation in path.Value!.AsObject().Where(x => x.Key is "get" or "post" or "put" or "patch" or "delete"))
            Assert.Contains(endpoints, e => e.RoutePattern.RawText == "/api/v1" + path.Key && e.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Contains(operation.Key.ToUpperInvariant()));
    }
    [Fact]
    public void Http_collection_covers_every_OpenAPI_operation()
    {
        var collection = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "CampusConnect.http"));
        var requests = System.Text.RegularExpressions.Regex.Matches(collection, @"(?m)^(GET|POST|PUT|PATCH|DELETE) \{\{baseUrl\}\}([^\r\n?]+)")
            .Select(m => (Method: m.Groups[1].Value, Path: m.Groups[2].Value.Replace("{{complaintId}}", "{id}").Replace("{{createComplaint.response.body.$.data.id}}", "{id}").Replace("demo-001", "{id}").Replace("demo-002", "{id}"))).ToHashSet();
        foreach (var path in Contract["paths"]!.AsObject())
        foreach (var operation in path.Value!.AsObject().Where(x => x.Key is "get" or "post" or "put" or "patch" or "delete"))
            Assert.Contains((operation.Key.ToUpperInvariant(), path.Key), requests);
    }
    [Theory]
    [InlineData("/health", "get", 200)]
    [InlineData("/meta/categories", "get", 200)]
    [InlineData("/auth/me", "get", 200)]
    [InlineData("/complaints", "get", 200)]
    [InlineData("/complaints/{id}", "get", 200)]
    [InlineData("/notifications", "get", 200)]
    [InlineData("/analytics/summary", "get", 200)]
    [InlineData("/analytics/by-department", "get", 200)]
    [InlineData("/analytics/by-status", "get", 200)]
    [InlineData("/analytics/trend", "get", 200)]
    [InlineData("/analytics/recurring", "get", 200)]
    public async Task Responses_validate_against_OpenAPI_31_schemas(string path, string method, int status)
    {
        using var client = await factory.Login("super");
        var response = await client.GetAsync("/api/v1" + path.Replace("{id}", "demo-000"));
        Assert.Equal(status, (int)response.StatusCode);
        var schema = Contract["paths"]![path]![method]!["responses"]![status.ToString()]!["content"]!["application/json"]!["schema"]!;
        Validate(schema, await response.Content.ReadAsStringAsync());
    }
    [Fact]
    public async Task Auth_and_error_responses_validate_against_contract()
    {
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = "student@campusconnect.edu", password = factory.SeedPassword });
        Validate(new JsonObject { ["$ref"] = "#/components/schemas/AuthResponse" }, await response.Content.ReadAsStringAsync());
        var error = await client.GetAsync("/api/v1/auth/me");
        Validate(new JsonObject { ["$ref"] = "#/components/schemas/Error" }, await error.Content.ReadAsStringAsync());
    }
    [Fact]
    public void Http_collection_has_no_response_dependent_global_variables()
    {
        var collection = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "CampusConnect.http"));
        Assert.DoesNotMatch(@"(?m)^@\w+\s*=.*\.response\.", collection);
    }
    private static void Validate(JsonNode schema, string payload)
    {
        var root = schema.DeepClone().AsObject();
        root["$schema"] = "https://json-schema.org/draft/2020-12/schema";
        root["$defs"] = Contract["components"]!["schemas"]!.DeepClone();
        static void Normalize(JsonNode? node)
        {
            if (node is JsonObject obj)
            {
                // OpenAPI's singular example annotation is not a JSON Schema keyword.
                obj.Remove("example");
                if (obj["$ref"] is JsonValue reference)
                    obj["$ref"] = reference.GetValue<string>().Replace("#/components/schemas/", "#/$defs/");
                foreach (var child in obj.ToArray()) Normalize(child.Value);
            }
            else if (node is JsonArray array) foreach (var child in array) Normalize(child);
        }
        Normalize(root);
        var compiled = JsonSchema.FromText(root.ToJsonString());
        using var instance = JsonDocument.Parse(payload);
        var result = compiled.Evaluate(instance.RootElement, new EvaluationOptions { OutputFormat = OutputFormat.List });
        Assert.True(result.IsValid, JsonSerializer.Serialize(result));
    }
}
