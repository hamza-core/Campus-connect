using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace CampusConnect.Api;
public record JwtSettings(string Secret);
public class CurrentUser(IHttpContextAccessor accessor, AppDb db)
{
    private User? cached;
    public async Task<User> Get() => cached ??= await db.Users.Include(x => x.Department)
        .SingleOrDefaultAsync(x => x.Id == accessor.HttpContext!.User.FindFirstValue("sub"))
        ?? throw new ApiError(401, "UNAUTHORIZED", "A valid bearer token is required.");
}
public class AuthService(AppDb db, JwtSettings settings)
{
    public async Task<object> Register(RegisterRequest r)
    {
        if (Encoding.UTF8.GetByteCount(r.Password) > 72) throw ApiError.Invalid("Password must be at most 72 UTF-8 bytes.");
        var email = r.Email.Trim().ToLowerInvariant();
        if (await db.Users.AnyAsync(x => x.Email == email)) throw new ApiError(409, "CONFLICT", "Email is already registered.");
        var user = new User { Name = r.Name.Trim(), Email = email, StudentId = r.StudentId, PasswordHash = BCrypt.Net.BCrypt.HashPassword(r.Password, 10) };
        db.Users.Add(user); await db.SaveChangesAsync();
        return Token(user);
    }
    public async Task<object> Login(LoginRequest r)
    {
        var user = await db.Users.Include(x => x.Department).SingleOrDefaultAsync(x => x.Email == r.Email.Trim().ToLowerInvariant());
        const string dummy = "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy";
        var valid = Encoding.UTF8.GetByteCount(r.Password) <= 72 && BCrypt.Net.BCrypt.Verify(r.Password, user?.PasswordHash ?? dummy);
        if (user is null || !valid) throw new ApiError(401, "UNAUTHORIZED", "Invalid email or password");
        return Token(user);
    }
    private object Token(User u)
    {
        var token = new JwtSecurityToken("CampusConnect", "CampusConnect", [new Claim("sub", u.Id), new Claim("role", u.Role)],
            expires: DateTime.UtcNow.AddDays(7), signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.Secret)), SecurityAlgorithms.HmacSha256));
        return new { token = new JwtSecurityTokenHandler().WriteToken(token), user = Views.User(u) };
    }
}
public static class Scope
{
    public static IQueryable<Complaint> Apply(IQueryable<Complaint> q, User u) => u.Role switch
    {
        Roles.Student => q.Where(x => x.AuthorId == u.Id),
        Roles.Admin => q.Where(x => x.DepartmentId == u.DepartmentId && u.DepartmentId != null),
        Roles.Super => q,
        _ => throw ApiError.Forbidden()
    };
    public static void Check(Complaint c, User u)
    {
        if (u.Role == Roles.Super || u.Role == Roles.Student && c.AuthorId == u.Id || u.Role == Roles.Admin && u.DepartmentId != null && c.DepartmentId == u.DepartmentId) return;
        throw ApiError.Forbidden();
    }
    public static void Admin(User u) { if (u.Role is not (Roles.Admin or Roles.Super)) throw ApiError.Forbidden(); }
    public static void DepartmentAdmin(User u) { if (u.Role != Roles.Admin) throw ApiError.Forbidden(); }
    public static void Student(User u) { if (u.Role != Roles.Student) throw ApiError.Forbidden(); }
}
[Authorize]
public class NotificationHub(CurrentUser current) : Hub
{
    public override async Task OnConnectedAsync()
    {
        var user = await current.Get();
        await Groups.AddToGroupAsync(Context.ConnectionId, "user:" + user.Id);
        await base.OnConnectedAsync();
    }
    // Clients cannot join arbitrary groups.
}
