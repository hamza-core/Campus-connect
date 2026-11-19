using Microsoft.EntityFrameworkCore;

namespace CampusConnect.Api;
public static class Seed
{
    public static string RequirePassword(IConfiguration configuration) => ValidatePassword(configuration["SEED_PASSWORD"]);
    private static string ValidatePassword(string? password)
    {
        if (string.IsNullOrEmpty(password) || password.Length < 8 || System.Text.Encoding.UTF8.GetByteCount(password) > 72)
            throw new InvalidOperationException("SEED_PASSWORD is required for explicit demo seeding and must contain at least 8 characters and at most 72 UTF-8 bytes.");
        return password;
    }
    public static async Task Run(AppDb db, string password)
    {
        password = ValidatePassword(password);
        foreach (var c in Catalog.Categories)
            if (!await db.Departments.AnyAsync(x => x.Slug == c.Slug)) db.Departments.Add(new Department { Id = "dept-" + c.Slug, Name = c.Label + " Administration", Slug = c.Slug });
        await db.SaveChangesAsync();
        var departments = await db.Departments.ToDictionaryAsync(x => x.Slug);
        var accounts = new[] { ("super", Roles.Super, (string?)null), ("cafeteria", Roles.Admin, "cafeteria"), ("library", Roles.Admin, "library"),
            ("labit", Roles.Admin, "lab-it"), ("academic", Roles.Admin, "academic"), ("student", Roles.Student, (string?)null), ("student2", Roles.Student, (string?)null) };
        var hash = BCrypt.Net.BCrypt.HashPassword(password, 10);
        foreach (var (name, role, slug) in accounts)
        {
            var existing = await db.Users.SingleOrDefaultAsync(x => x.Email == name + "@campusconnect.edu");
            if (existing is null)
                db.Users.Add(new User { Id = "user-" + name, Name = name, Email = name + "@campusconnect.edu", PasswordHash = hash, Role = role, DepartmentId = slug is null ? null : departments[slug].Id });
            else existing.PasswordHash = hash;
        }
        await db.SaveChangesAsync();
        if (await db.Complaints.AnyAsync()) return;
        await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        var now = DateTime.UtcNow; var counter = await db.TicketCounters.FindAsync(now.Year);
        if (counter is null) { counter = new TicketCounter { Year = now.Year }; db.Add(counter); }
        for (var i = 0; i < 40; i++)
        {
            var category = Catalog.Categories[i % 4]; var created = now.AddDays(-(i % 14)).AddMinutes(-i);
            var status = Catalog.Statuses[(i / 4) % 4]; var author = "user-student" + (i % 2 == 0 ? "" : "2");
            var priority = Catalog.Priorities[i % 3]; counter.Value++;
            var c = new Complaint { Id = $"demo-{i:D3}", Ticket = $"CC-{now.Year}-{counter.Value:D4}", Sequence = counter.Value,
                AuthorId = author, DepartmentId = departments[category.Slug].Id, Category = category.Key,
                SubIssue = category.Issues[i % category.Issues.Length], Title = category.Label + " issue " + (i + 1),
                Description = "Demo complaint for " + category.Label + ". Please investigate and provide an update.", Priority = priority, Status = status,
                CreatedAt = created, UpdatedAt = created.AddHours(2), DueAt = Catalog.Due(created, priority), ResolvedAt = status == "RESOLVED" ? created.AddHours(2) : null,
                AnonymousToStaff = i % 5 == 0 };
            c.Timeline.Add(new TimelineEntry { ActorId = author, Type = "CREATED", ToStatus = "PENDING", CreatedAt = created });
            if (status != "PENDING") c.Timeline.Add(new TimelineEntry { ActorId = "user-" + (category.Slug == "lab-it" ? "labit" : category.Slug), Type = "STATUS_CHANGE", FromStatus = "PENDING", ToStatus = "IN_PROGRESS", CreatedAt = created.AddHours(1) });
            if (status is "RESOLVED" or "REJECTED") c.Timeline.Add(new TimelineEntry { ActorId = "user-super", Type = "STATUS_CHANGE", FromStatus = "IN_PROGRESS", ToStatus = status, Body = "Demo action completed.", CreatedAt = created.AddHours(2) });
            if (i % 3 == 0) c.Supports.Add(new Support { UserId = author == "user-student" ? "user-student2" : "user-student" });
            if (status == "RESOLVED") c.Feedback = new Feedback { Rating = i % 5 + 1, Comment = "Thank you for the response." };
            db.Complaints.Add(c);
        }
        await db.SaveChangesAsync(); await tx.CommitAsync();
    }
}
