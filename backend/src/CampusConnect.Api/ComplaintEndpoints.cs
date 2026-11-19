using System.Text;
using Microsoft.EntityFrameworkCore;

namespace CampusConnect.Api;
public static class ComplaintEndpoints
{
    public static void MapComplaintEndpoints(this WebApplication app)
    {
        var api = app.MapGroup("/api/v1").RequireAuthorization().AddEndpointFilter<ValidationFilter>();
        api.MapPost("/complaints", async (CreateComplaintRequest r, ComplaintService s) => Results.Json(new { data = await s.Create(r) }, statusCode: 201)).RequireAuthorization(p => p.RequireRole(Roles.Student));
        api.MapGet("/complaints", async (HttpRequest request, CurrentUser current, ComplaintService s) =>
        {
            var u = await current.Get(); var page = ComplaintQuery.Number(request, "page", 1, int.MaxValue);
            var pageSize = ComplaintQuery.Number(request, "pageSize", 20, 100);
            if ((long)(page - 1) * pageSize > int.MaxValue) throw ApiError.Invalid("Page exceeds the supported range.");
            var q = ComplaintQuery.Filter(s.Full.AsNoTracking(), u, request); var total = await q.CountAsync();
            var rows = await q.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();
            return Results.Ok(new { data = rows.Select(c => Views.Complaint(c, u)), page, pageSize, total });
        });
        api.MapGet("/complaints/{id}", async (string id, ComplaintService s, CurrentUser u) => Results.Ok(new { data = Views.Complaint(await s.Load(id), await u.Get(), true) }));
        api.MapPatch("/complaints/{id}/status", async (string id, StatusRequest r, ComplaintService s) => Results.Ok(new { data = await s.ChangeStatus(id, r) })).RequireAuthorization(p => p.RequireRole(Roles.Admin));
        api.MapPost("/complaints/{id}/comments", async (string id, CommentRequest r, ComplaintService s) => Results.Json(new { data = await s.Comment(id, r) }, statusCode: 201)).RequireAuthorization(p => p.RequireRole(Roles.Admin));
        api.MapPost("/complaints/{id}/feedback", async (string id, FeedbackRequest r, ComplaintService s) => Results.Json(new { data = await s.Feedback(id, r) }, statusCode: 201)).RequireAuthorization(p => p.RequireRole(Roles.Student));
        api.MapPut("/complaints/{id}/support", async (string id, ComplaintService s) => Results.Ok(await s.Support(id, true))).RequireAuthorization(p => p.RequireRole(Roles.Student));
        api.MapDelete("/complaints/{id}/support", async (string id, ComplaintService s) => Results.Ok(await s.Support(id, false))).RequireAuthorization(p => p.RequireRole(Roles.Student));
        api.MapGet("/notifications", async (AppDb db, CurrentUser current, HttpRequest request) =>
        {
            var u = await current.Get(); var q = db.Notifications.AsNoTracking().Where(x => x.UserId == u.Id);
            var unreadCount = await q.CountAsync(x => !x.Read);
            if (ComplaintQuery.Boolean(request, "unreadOnly") == true) q = q.Where(x => !x.Read);
            var rows = await q.OrderByDescending(x => x.CreatedAt).ToListAsync();
            return Results.Ok(new { data = rows.Select(x => new { x.Id, x.Message, x.ComplaintId, x.Read, x.CreatedAt }), unreadCount });
        });
        api.MapPost("/notifications/read-all", async (AppDb db, CurrentUser current) =>
        {
            var u = await current.Get(); await db.Notifications.Where(x => x.UserId == u.Id && !x.Read).ExecuteUpdateAsync(s => s.SetProperty(x => x.Read, true));
            return Results.NoContent();
        });
        api.MapPost("/uploads/sign", async (UploadRequest r, CurrentUser current, S3Uploads uploads) =>
            Results.Ok(new { data = uploads.Sign(r, await current.Get()) })).RequireAuthorization(p => p.RequireRole(Roles.Student));
        api.MapGet("/admin/complaints/export.csv", async (CurrentUser current, ComplaintService s, HttpRequest r) =>
        {
            var u = await current.Get(); Scope.Admin(u);
            var rows = await ComplaintQuery.Filter(s.Full.AsNoTracking(), u, r).ToListAsync();
            static string Cell(string v)
            {
                if (v.StartsWith('\t') || v.StartsWith('\r') || v.TrimStart().StartsWith('=') || v.TrimStart().StartsWith('+') || v.TrimStart().StartsWith('-') || v.TrimStart().StartsWith('@')) v = "'" + v;
                return "\"" + v.Replace("\"", "\"\"") + "\"";
            }
            var csv = new StringBuilder("ticket,title,category,department,status,priority,createdAt\r\n");
            foreach (var c in rows) csv.AppendLine(string.Join(',', new[] { c.Ticket, c.Title, c.Category, c.Department.Name, c.Status, c.Priority, c.CreatedAt.ToString("O") }.Select(Cell)));
            return Results.File(Encoding.UTF8.GetBytes(csv.ToString()), "text/csv", "complaints.csv");
        }).RequireAuthorization(p => p.RequireRole(Roles.Admin, Roles.Super));
    }
}
