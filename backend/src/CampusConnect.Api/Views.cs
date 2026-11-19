namespace CampusConnect.Api;
public static class Views
{
    public static object Department(Department d) => new { d.Id, d.Name, d.Slug };
    public static object User(User u) => new { u.Id, u.Name, u.Email, u.Role, u.StudentId, department = u.Department is null ? null : Department(u.Department) };
    public static object Timeline(TimelineEntry t, Complaint c, User caller) => new
    {
        t.Id, t.Type, t.FromStatus, t.ToStatus, t.Body, t.CreatedAt,
        actor = new { name = c.AnonymousToStaff && caller.Role == Roles.Admin && t.ActorId == c.AuthorId ? "Anonymous student" : t.Actor.Name, role = t.Actor.Role }
    };
    public static object Complaint(Complaint c, User u, bool detail = false)
    {
        var result = new Dictionary<string, object?>
        {
            ["id"] = c.Id, ["ticket"] = c.Ticket, ["title"] = c.Title, ["description"] = c.Description,
            ["category"] = c.Category, ["subIssue"] = c.SubIssue, ["department"] = Department(c.Department),
            ["status"] = c.Status, ["priority"] = c.Priority, ["location"] = c.Location, ["imageUrls"] = c.ImageUrls,
            ["supportCount"] = c.Supports.Count, ["supportedByMe"] = c.Supports.Any(s => s.UserId == u.Id),
            ["isOverdue"] = (c.Status is "PENDING" or "IN_PROGRESS") && c.DueAt < DateTime.UtcNow, ["dueAt"] = c.DueAt,
            ["author"] = c.AnonymousToStaff && u.Role == Roles.Admin ? null : new { c.Author.Id, c.Author.Name, c.Author.StudentId },
            ["createdAt"] = c.CreatedAt, ["updatedAt"] = c.UpdatedAt, ["resolvedAt"] = c.ResolvedAt, ["rowVersion"] = c.Version
        };
        if (detail)
        {
            result["timeline"] = c.Timeline.OrderBy(t => t.CreatedAt).ThenBy(t => t.Id).Select(t => Timeline(t, c, u));
            result["feedback"] = c.Feedback is null ? null : new { c.Feedback.Rating, c.Feedback.Comment };
            result["allowedTransitions"] = Catalog.Transitions(c.Status, u.Role);
        }
        return result;
    }
}
