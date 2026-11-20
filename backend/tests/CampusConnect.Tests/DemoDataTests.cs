using CampusConnect.Api;
using Xunit;

namespace CampusConnect.Tests;

public class DemoDataTests
{
    private static readonly DateTime Now = new(2026, 11, 21, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Demo_data_is_valid_for_the_workflow_and_catalog()
    {
        var (complaints, notifications) = DemoData.Build(Now);
        Assert.InRange(complaints.Count, 40, 60);
        Assert.Equal(complaints.Count, complaints.Select(c => c.Ticket).Distinct().Count());
        foreach (var c in complaints)
        {
            var category = Catalog.Categories.Single(x => x.Key == c.Category);
            Assert.Contains(c.SubIssue, category.Issues);
            Assert.Equal("dept-" + category.Slug, c.DepartmentId);
            Assert.Contains(c.Status, Catalog.Statuses);
            Assert.Contains(c.Priority, Catalog.Priorities);
            Assert.InRange(c.Title.Length, 5, 120);
            Assert.InRange(c.Description.Length, 20, 3000);
            Assert.True(c.CreatedAt <= Now && c.UpdatedAt <= Now && c.UpdatedAt >= c.CreatedAt, c.Ticket);
            Assert.Equal(Catalog.Due(c.CreatedAt, c.Priority), c.DueAt);
            Assert.Equal("CREATED", c.Timeline[0].Type);
            Assert.Equal(c.Timeline.OrderBy(t => t.CreatedAt).Select(t => t.Id), c.Timeline.Select(t => t.Id));
            if (c.Status is "RESOLVED" or "REJECTED")
                Assert.False(string.IsNullOrWhiteSpace(c.Timeline[^1].Body), c.Ticket + " needs a closing remark");
            Assert.Equal(c.Status == "RESOLVED", c.ResolvedAt is not null);
            if (c.Feedback is not null) { Assert.Equal("RESOLVED", c.Status); Assert.InRange(c.Feedback.Rating, 1, 5); }
        }
        Assert.All(notifications, n => Assert.Contains(complaints, c => c.Id == n.ComplaintId && c.AuthorId == n.UserId));
    }

    [Fact]
    public void Demo_data_has_a_believable_mix()
    {
        var (complaints, _) = DemoData.Build(Now);
        foreach (var status in Catalog.Statuses) Assert.Contains(complaints, c => c.Status == status);
        foreach (var category in Catalog.Categories) Assert.True(complaints.Count(c => c.Category == category.Key) >= 8, category.Key);
        Assert.True(complaints.Count(c => c.Status is "PENDING" or "IN_PROGRESS" && c.DueAt < Now) >= 2, "some overdue");
        Assert.True(complaints.Count(c => c.CreatedAt > Now.AddDays(-14)) >= 20, "recent activity for the trend chart");
        Assert.True(complaints.Select(c => c.AuthorId).Distinct().Count() >= 5);
    }

    [Fact]
    public void Reset_refuses_without_confirmation()
    {
        var config = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();
        Assert.Throws<InvalidOperationException>(() => DemoData.RequireConfirmation(config));
    }
}
