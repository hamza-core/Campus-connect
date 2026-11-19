using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace CampusConnect.Api;

public static class Roles
{
    public const string Student = "STUDENT", Admin = "DEPT_ADMIN", Super = "SUPER_ADMIN";
}
public static class Catalog
{
    public static readonly string[] Statuses = ["PENDING", "IN_PROGRESS", "RESOLVED", "REJECTED"];
    public static readonly string[] Priorities = ["LOW", "MEDIUM", "HIGH"];
    public static readonly (string Key, string Slug, string Label, string[] Issues)[] Categories =
    [
        ("CAFETERIA", "cafeteria", "Cafeteria", ["Poor food quality or hygiene", "High food prices", "Limited food variety", "Unprofessional staff behaviour or poor service"]),
        ("LIBRARY", "library", "Library", ["Insufficient or outdated books and learning resources", "Librarian availability or staff behaviour", "Library opening and closing hours", "Insufficient seating or study space"]),
        ("LAB_IT", "lab-it", "Labs & IT", ["Non-functional computers", "Internet connectivity issues", "Projector or multimedia equipment problems", "Missing or unavailable software"]),
        ("ACADEMIC", "academic", "Teaching & Academic", ["Teachers arriving late to lectures", "Unavailability of lecture notes or learning materials", "Inadequate explanation of course topics", "Classroom management or discipline issues"])
    ];
    public static string[] Transitions(string status, string role) => role != Roles.Admin ? [] : status switch
    {
        "PENDING" => ["IN_PROGRESS", "REJECTED"],
        "IN_PROGRESS" => ["RESOLVED", "REJECTED"],
        _ => []
    };
    public static DateTime Due(DateTime created, string priority) => created.AddHours(priority switch { "HIGH" => 24, "LOW" => 168, _ => 72 });
}
public abstract class Entity { [MaxLength(40)] public string Id { get; set; } = Guid.NewGuid().ToString("N"); }
public class Department : Entity
{
    [MaxLength(100)] public string Name { get; set; } = "";
    [MaxLength(30)] public string Slug { get; set; } = "";
}
public class User : Entity
{
    [MaxLength(80)] public string Name { get; set; } = "";
    [MaxLength(254)] public string Email { get; set; } = "";
    [MaxLength(100)] public string PasswordHash { get; set; } = "";
    [MaxLength(20)] public string Role { get; set; } = Roles.Student;
    [MaxLength(30)] public string? StudentId { get; set; }
    [MaxLength(40)] public string? DepartmentId { get; set; }
    public Department? Department { get; set; }
}
public class Complaint : Entity
{
    public int Sequence { get; set; }
    [MaxLength(30)] public string Ticket { get; set; } = "";
    [MaxLength(40)] public string AuthorId { get; set; } = "";
    public User Author { get; set; } = null!;
    [MaxLength(40)] public string DepartmentId { get; set; } = "";
    public Department Department { get; set; } = null!;
    [MaxLength(20)] public string Category { get; set; } = "";
    [MaxLength(120)] public string? SubIssue { get; set; }
    [MaxLength(120)] public string Title { get; set; } = "";
    [MaxLength(3000)] public string Description { get; set; } = "";
    [MaxLength(20)] public string Status { get; set; } = "PENDING";
    [MaxLength(10)] public string Priority { get; set; } = "MEDIUM";
    [MaxLength(120)] public string? Location { get; set; }
    public string[] ImageUrls { get; set; } = [];
    public bool AnonymousToStaff { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public DateTime DueAt { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public Guid Version { get; set; } = Guid.NewGuid();
    public List<TimelineEntry> Timeline { get; set; } = [];
    public List<Support> Supports { get; set; } = [];
    public Feedback? Feedback { get; set; }
}
public class TimelineEntry : Entity
{
    [MaxLength(40)] public string ComplaintId { get; set; } = "";
    [MaxLength(40)] public string ActorId { get; set; } = "";
    public User Actor { get; set; } = null!;
    [MaxLength(20)] public string Type { get; set; } = "CREATED";
    [MaxLength(20)] public string? FromStatus { get; set; }
    [MaxLength(20)] public string? ToStatus { get; set; }
    [MaxLength(2000)] public string? Body { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
public class Support
{
    [MaxLength(40)] public string UserId { get; set; } = "";
    [MaxLength(40)] public string ComplaintId { get; set; } = "";
}
public class Feedback
{
    [MaxLength(40)] public string ComplaintId { get; set; } = "";
    public int Rating { get; set; }
    [MaxLength(500)] public string? Comment { get; set; }
}
public class Notification : Entity
{
    [MaxLength(40)] public string UserId { get; set; } = "";
    [MaxLength(40)] public string ComplaintId { get; set; } = "";
    [MaxLength(2200)] public string Message { get; set; } = "";
    public bool Read { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
// One counter per year, locked by a serializable create transaction.
public class TicketCounter { public int Year { get; set; } public int Value { get; set; } }
public class AppDb(DbContextOptions<AppDb> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Department> Departments => Set<Department>();
    public DbSet<Complaint> Complaints => Set<Complaint>();
    public DbSet<TimelineEntry> Timeline => Set<TimelineEntry>();
    public DbSet<Support> Supports => Set<Support>();
    public DbSet<Feedback> Feedback => Set<Feedback>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<TicketCounter> TicketCounters => Set<TicketCounter>();
    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>().HasIndex(x => x.Email).IsUnique();
        b.Entity<Department>().HasIndex(x => x.Slug).IsUnique();
        b.Entity<Complaint>().HasIndex(x => x.Ticket).IsUnique();
        b.Entity<Complaint>().HasIndex(x => new { x.DepartmentId, x.Status });
        b.Entity<Complaint>().HasIndex(x => x.AuthorId);
        b.Entity<Complaint>().HasIndex(x => new { x.Category, x.SubIssue });
        b.Entity<Complaint>().HasIndex(x => x.CreatedAt);
        b.Entity<Complaint>().Property(x => x.Version).IsConcurrencyToken();
        b.Entity<Complaint>().Property(x => x.ImageUrls).HasColumnType("nvarchar(max)");
        b.Entity<Support>().HasKey(x => new { x.UserId, x.ComplaintId });
        b.Entity<Support>().HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
        b.Entity<Support>().HasOne<Complaint>().WithMany(x => x.Supports).HasForeignKey(x => x.ComplaintId);
        b.Entity<Feedback>().HasKey(x => x.ComplaintId);
        b.Entity<Complaint>().HasOne(x => x.Feedback).WithOne().HasForeignKey<Feedback>(x => x.ComplaintId);
        b.Entity<TicketCounter>().HasKey(x => x.Year);
        b.Entity<TicketCounter>().Property(x => x.Year).ValueGeneratedNever();
        b.Entity<Notification>().HasIndex(x => new { x.UserId, x.Read });
        b.Entity<Notification>().HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
        b.Entity<Notification>().HasOne<Complaint>().WithMany().HasForeignKey(x => x.ComplaintId);
        // SQL Server disallows multiple cascade paths through authors/departments.
        b.Entity<Complaint>().HasOne(x => x.Author).WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.NoAction);
        b.Entity<Complaint>().HasOne(x => x.Department).WithMany().HasForeignKey(x => x.DepartmentId).OnDelete(DeleteBehavior.NoAction);
        b.Entity<TimelineEntry>().HasOne(x => x.Actor).WithMany().HasForeignKey(x => x.ActorId).OnDelete(DeleteBehavior.NoAction);
        // SQL Server datetime2 does not store DateTime.Kind; restore UTC at the boundary.
        var utc = new ValueConverter<DateTime, DateTime>(value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
        foreach (var entity in b.Model.GetEntityTypes())
        foreach (var property in entity.GetProperties())
            if (property.ClrType == typeof(DateTime) || property.ClrType == typeof(DateTime?)) property.SetValueConverter(utc);
    }
}
