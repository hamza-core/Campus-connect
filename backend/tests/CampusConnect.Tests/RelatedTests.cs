using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;

namespace CampusConnect.Tests;

public class RelatedTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private static async Task<string> Create(HttpClient client, string title, string subIssue)
    {
        var response = await client.PostAsJsonAsync("/api/v1/complaints", new
        {
            category = "LAB_IT", title, description = "Related complaint test for the projector.", subIssue
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<JsonObject>())!["data"]!["id"]!.GetValue<string>();
    }

    [Fact]
    public async Task Related_returns_same_issue_in_scope_and_not_itself()
    {
        using var student = await factory.Login("student");
        var label = "Related test " + Guid.NewGuid().ToString("N")[..8];
        var first = await Create(student, "Projector flickers", label);
        var second = await Create(student, "Projector shows no signal", label);
        await Create(student, "Unrelated wifi problem", "Different issue " + label);

        using var admin = await factory.Login("labit");
        var response = await admin.GetAsync($"/api/v1/complaints/{first}/related");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = (await response.Content.ReadFromJsonAsync<JsonObject>())!;
        var ids = body["data"]!.AsArray().Select(x => x!["id"]!.GetValue<string>()).ToList();
        Assert.Equal([second], ids);
        Assert.Equal(1, body["total"]!.GetValue<int>());

        using var library = await factory.Login("library");
        Assert.Equal(HttpStatusCode.Forbidden, (await library.GetAsync($"/api/v1/complaints/{first}/related")).StatusCode);
    }

    [Fact]
    public async Task Year_and_month_filters_narrow_the_list()
    {
        using var super = await factory.Login("super");
        var now = DateTime.UtcNow;
        async Task<int> Total(string query) =>
            (await (await super.GetAsync("/api/v1/complaints?pageSize=1&" + query)).Content.ReadFromJsonAsync<JsonObject>())!["total"]!.GetValue<int>();
        Assert.Equal(0, await Total("year=2001"));
        Assert.True(await Total($"year={now.Year}") > 0);
        Assert.True(await Total($"year={now.Year}&month={now.Month}") > 0);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await super.GetAsync("/api/v1/complaints?year=1999")).StatusCode);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await super.GetAsync("/api/v1/complaints?year=2026&month=13")).StatusCode);
    }
}
