using System.Data;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace CampusConnect.Api;
public class ComplaintService(AppDb db, CurrentUser current, IHubContext<NotificationHub> hub, ILogger<ComplaintService> log, TimeProvider clock, Vision.UploadStore uploads)
{
    public IQueryable<Complaint> Full => db.Complaints.Include(x => x.Author).Include(x => x.Department)
        .Include(x => x.Supports).Include(x => x.Feedback).Include(x => x.Timeline).ThenInclude(x => x.Actor).AsSplitQuery();
    public async Task<Complaint> Load(string id)
    {
        var user = await current.Get();
        var c = await Full.SingleOrDefaultAsync(x => x.Id == id) ?? throw new ApiError(404, "NOT_FOUND", "Complaint not found.");
        Scope.Check(c, user); return c;
    }
    // Images are kept on the device for now: any submitted imageUrls are ignored and nothing is stored.
    private string[] ValidImages(string[]? urls) => (urls ?? []).Distinct().Take(3).Select(u =>
        Vision.UploadStore.IdFromUrl(u) is { } id && uploads.Find(id) is not null ? u
        : throw new ApiError(422, "VALIDATION_FAILED", "A photo reference is invalid. Upload the photo again.")).ToArray();

    public async Task<object> Create(CreateComplaintRequest r)
    {
        var user = await current.Get(); Scope.Student(user);
        var category = Catalog.Categories.Single(x => x.Key == r.Category);
        var department = await db.Departments.SingleAsync(x => x.Slug == category.Slug);
        for (var attempt = 0; ; attempt++)
        {
            await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            try
            {

                var now = clock.GetUtcNow().UtcDateTime;
                var counter = await db.TicketCounters.FindAsync(now.Year);
                if (counter is null) { counter = new TicketCounter { Year = now.Year }; db.Add(counter); }
                counter.Value++;
                var c = new Complaint
                {
                    Sequence = counter.Value, Ticket = $"CC-{now.Year}-{counter.Value:D4}", Author = user, Department = department,
                    Category = r.Category, Title = r.Title.Trim(), Description = r.Description.Trim(), Priority = r.Priority ?? "MEDIUM",
                    SubIssue = r.SubIssue, Location = r.Location, ImageUrls = ValidImages(r.ImageUrls), AnonymousToStaff = r.AnonymousToStaff,
                    CreatedAt = now, UpdatedAt = now, DueAt = Catalog.Due(now, r.Priority ?? "MEDIUM")
                };
                c.Timeline.Add(new TimelineEntry { Actor = user, Type = "CREATED", ToStatus = "PENDING", CreatedAt = now });
                db.Complaints.Add(c); await db.SaveChangesAsync(); await transaction.CommitAsync();
                return Views.Complaint(c, user);
            }
            catch (Exception error) when (attempt == 0 && DatabaseConflicts.IsRace(error))
            {
                // Disposal rolls back the failed transaction; reload the counter on the second attempt.
                db.ChangeTracker.Clear(); db.Attach(user); db.Attach(department);
            }
        }
    }

    public async Task<object> ChangeStatus(string id, StatusRequest r)
    {
        var user = await current.Get(); Scope.DepartmentAdmin(user);
        var c = await Load(id);
        if (r.RowVersion is null) throw ApiError.Invalid("rowVersion is required.");
        if (r.RowVersion != c.Version) throw new ApiError(409, "CONFLICT", "The complaint changed. Reload it and retry.");
        if (!Catalog.Transitions(c.Status, user.Role).Contains(r.Status)) throw new ApiError(409, "INVALID_TRANSITION", "This status transition is not allowed.");
        if (r.Status is "RESOLVED" or "REJECTED" && string.IsNullOrWhiteSpace(r.Remark)) throw ApiError.Invalid("A remark is required for resolution or rejection.");
        var entry = new TimelineEntry { ComplaintId = c.Id, Actor = user, Type = "STATUS_CHANGE", FromStatus = c.Status, ToStatus = r.Status, Body = r.Remark };
        c.Status = r.Status; c.UpdatedAt = DateTime.UtcNow; c.Version = Guid.NewGuid();
        c.ResolvedAt = r.Status == "RESOLVED" ? c.UpdatedAt : null;
        c.Timeline.Add(entry);
        var notification = Notify(c, $"{c.Ticket}: {r.Status}" + (r.Remark is null ? "" : $" — {r.Remark}"));
        await db.SaveChangesAsync(); // EF wraps the complaint, timeline, and notification in one transaction.
        await Publish(notification);
        return Views.Complaint(c, user, true);
    }
    public async Task<object> Comment(string id, CommentRequest r)
    {
        var user = await current.Get(); Scope.DepartmentAdmin(user); var c = await Load(id);
        var entry = new TimelineEntry { ComplaintId = id, Actor = user, Type = "REMARK", Body = r.Body.Trim() };
        c.Timeline.Add(entry); c.UpdatedAt = DateTime.UtcNow; c.Version = Guid.NewGuid();
        var notification = c.AuthorId == user.Id ? null : Notify(c, $"{c.Ticket}: {r.Body.Trim()}");
        await db.SaveChangesAsync();
        if (notification is not null) await Publish(notification);
        return Views.Timeline(entry, c, user);
    }
    public async Task<object> Feedback(string id, FeedbackRequest r)
    {
        var u = await current.Get(); Scope.Student(u); var c = await Load(id);
        if (c.AuthorId != u.Id) throw ApiError.Forbidden();
        if (c.Status != "RESOLVED" || c.Feedback is not null) throw new ApiError(409, "CONFLICT", "Feedback requires a resolved complaint and may be submitted only once.");
        c.Feedback = new Feedback { ComplaintId = id, Rating = r.Rating, Comment = r.Comment };
        await db.SaveChangesAsync(); return Views.Complaint(c, u, true);
    }
    public async Task<object> Support(string id, bool enabled)
    {
        var u = await current.Get(); Scope.Student(u);
        // The current contract prohibits students from accessing other students' complaints.
        // Keep that security boundary until a discovery/support contract is approved.
        var c = await Load(id);
        if (c.AuthorId == u.Id) throw ApiError.Forbidden();
        var existing = await db.Supports.FindAsync(u.Id, id);
        if (enabled && existing is null) db.Supports.Add(new Support { UserId = u.Id, ComplaintId = id });
        if (!enabled && existing is not null) db.Supports.Remove(existing);
        await db.SaveChangesAsync();
        return new { supportCount = await db.Supports.CountAsync(x => x.ComplaintId == id), supportedByMe = enabled };
    }
    private Notification Notify(Complaint c, string message)
    {
        var n = new Notification { UserId = c.AuthorId, ComplaintId = c.Id, Message = message };
        db.Notifications.Add(n); return n;
    }
    private async Task Publish(Notification n)
    {
        try { await hub.Clients.Group("user:" + n.UserId).SendAsync("notification", new { n.Id, n.Message, n.ComplaintId, n.Read, n.CreatedAt }); }
        catch (Exception e) { log.LogWarning(e, "Live notification delivery failed; notification remains available via REST"); }
    }
}
public static class ComplaintQuery
{
    public static int Number(HttpRequest r, string key, int fallback, int max)
    {
        if (!r.Query.ContainsKey(key)) return fallback;
        if (!int.TryParse(r.Query[key], out var value) || value < 1 || value > max) throw ApiError.Invalid($"{key} must be between 1 and {max}.");
        return value;
    }
    public static bool? Boolean(HttpRequest r, string key)
    {
        if (!r.Query.ContainsKey(key)) return null;
        return bool.TryParse(r.Query[key], out var value) ? value : throw ApiError.Invalid($"{key} must be a boolean.");
    }
    public static IQueryable<Complaint> Filter(IQueryable<Complaint> q, User u, HttpRequest r)
    {
        q = Scope.Apply(q, u);
        foreach (var (key, allowed) in new[] { ("status", Catalog.Statuses), ("category", Catalog.Categories.Select(x => x.Key).ToArray()), ("priority", Catalog.Priorities) })
            if (r.Query.ContainsKey(key) && !allowed.Contains(r.Query[key].ToString())) throw ApiError.Invalid($"Invalid {key}.");
        if (r.Query.TryGetValue("status", out var status)) q = q.Where(x => x.Status == status.ToString());
        if (r.Query.TryGetValue("category", out var category)) q = q.Where(x => x.Category == category.ToString());
        if (r.Query.TryGetValue("priority", out var priority)) q = q.Where(x => x.Priority == priority.ToString());
        if (u.Role == Roles.Super && r.Query.TryGetValue("departmentId", out var department)) q = q.Where(x => x.DepartmentId == department.ToString());
        var overdue = Boolean(r, "overdue"); var now = DateTime.UtcNow;
        if (overdue is not null) q = q.Where(x => ((x.Status == "PENDING" || x.Status == "IN_PROGRESS") && x.DueAt < now) == overdue);
        if (r.Query.TryGetValue("q", out var search))
        {
            var term = search.ToString(); q = q.Where(x => x.Title.Contains(term) || x.Description.Contains(term) || x.Ticket.Contains(term));
        }
        return r.Query["sort"].ToString() switch
        {
            "" or "newest" => q.OrderByDescending(x => x.CreatedAt).ThenBy(x => x.Id),
            "oldest" => q.OrderBy(x => x.CreatedAt).ThenBy(x => x.Id),
            "mostSupported" => q.OrderByDescending(x => x.Supports.Count).ThenBy(x => x.Id),
            "priority" => q.OrderByDescending(x => x.Priority == "HIGH" ? 3 : x.Priority == "MEDIUM" ? 2 : 1).ThenByDescending(x => x.CreatedAt).ThenBy(x => x.Id),
            _ => throw ApiError.Invalid("Invalid sort.")
        };
    }
}
