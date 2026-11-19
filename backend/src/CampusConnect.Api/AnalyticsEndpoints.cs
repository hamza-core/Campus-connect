using Microsoft.EntityFrameworkCore;

namespace CampusConnect.Api;
public static class AnalyticsEndpoints
{
    public static void MapAnalyticsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/v1/analytics").RequireAuthorization(p => p.RequireRole(Roles.Admin, Roles.Super));
        async Task<IQueryable<Complaint>> Query(AppDb db, CurrentUser current, HttpRequest request)
        {
            var u = await current.Get(); Scope.Admin(u);
            var q = Scope.Apply(db.Complaints.AsNoTracking(), u);
            if (u.Role == Roles.Super && request.Query.TryGetValue("departmentId", out var department)) q = q.Where(x => x.DepartmentId == department.ToString());
            return q;
        }
        group.MapGet("/summary", async (AppDb db, CurrentUser user, HttpRequest request) =>
        {
            var q = await Query(db, user, request); var now = DateTime.UtcNow;
            var statuses = await q.GroupBy(x => x.Status).Select(g => new { status = g.Key, count = g.Count() }).ToDictionaryAsync(x => x.status, x => x.count);
            var dates = await q.Where(x => x.ResolvedAt != null).Select(x => new { x.CreatedAt, x.ResolvedAt }).ToListAsync();
            var ratings = await q.Where(x => x.Feedback != null).Select(x => (double?)x.Feedback!.Rating).AverageAsync();
            return Results.Ok(new { data = new { total = statuses.Values.Sum(), pending = statuses.GetValueOrDefault("PENDING"), inProgress = statuses.GetValueOrDefault("IN_PROGRESS"),
                resolved = statuses.GetValueOrDefault("RESOLVED"), rejected = statuses.GetValueOrDefault("REJECTED"),
                overdue = await q.CountAsync(x => (x.Status == "PENDING" || x.Status == "IN_PROGRESS") && x.DueAt < now),
                avgResolutionHours = dates.Count == 0 ? (double?)null : dates.Average(x => (x.ResolvedAt!.Value - x.CreatedAt).TotalHours), avgRating = ratings } });
        });
        group.MapGet("/by-department", async (AppDb db, CurrentUser user, HttpRequest request) =>
        {
            var u = await user.Get(); var q = await Query(db, user, request);
            var counts = await q.GroupBy(x => x.DepartmentId).Select(g => new { id = g.Key, count = g.Count() }).ToDictionaryAsync(x => x.id, x => x.count);
            var departments = await db.Departments.Where(x => u.Role == Roles.Super || x.Id == u.DepartmentId).ToListAsync();
            return Results.Ok(new { data = departments.Select(d => new { department = Views.Department(d), count = counts.GetValueOrDefault(d.Id) }) });
        });
        group.MapGet("/by-status", async (AppDb db, CurrentUser user, HttpRequest request) =>
        {
            var q = await Query(db, user, request);
            var counts = await q.GroupBy(x => x.Status).Select(g => new { status = g.Key, count = g.Count() }).ToDictionaryAsync(x => x.status, x => x.count);
            return Results.Ok(new { data = Catalog.Statuses.Select(status => new { status, count = counts.GetValueOrDefault(status) }) });
        });
        group.MapGet("/trend", async (AppDb db, CurrentUser user, HttpRequest request) =>
        {
            var days = ComplaintQuery.Number(request, "days", 14, 90); var start = DateTime.UtcNow.Date.AddDays(1 - days);
            var q = await Query(db, user, request);
            var counts = await q.Where(x => x.CreatedAt >= start).GroupBy(x => x.CreatedAt.Date).Select(g => new { day = g.Key, count = g.Count() }).ToDictionaryAsync(x => x.day, x => x.count);
            return Results.Ok(new { data = Enumerable.Range(0, days).Select(i => new { date = start.AddDays(i).ToString("yyyy-MM-dd"), count = counts.GetValueOrDefault(start.AddDays(i)) }) });
        });
        group.MapGet("/recurring", async (AppDb db, CurrentUser user, HttpRequest request) =>
        {
            var q = await Query(db, user, request);
            // Project support counts first: SQL Server cannot aggregate an aggregate subquery.
            var rows = await q.Select(x => new { x.Category, x.SubIssue, supports = x.Supports.Count }).ToListAsync();
            return Results.Ok(new { data = rows.GroupBy(x => new { x.Category, x.SubIssue }).Select(g => new { category = g.Key.Category, subIssue = g.Key.SubIssue ?? "General", count = g.Count(), supportTotal = g.Sum(x => x.supports) })
                .OrderByDescending(x => x.supportTotal + x.count).ThenBy(x => x.category).Take(10) });
        });
    }
}
