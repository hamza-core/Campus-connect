using System.ComponentModel.DataAnnotations;

namespace CampusConnect.Api;

public record RegisterRequest(
    [property: Required, StringLength(80, MinimumLength = 2)] string Name,
    [property: Required, EmailAddress, StringLength(254)] string Email,
    [property: Required, StringLength(72, MinimumLength = 8)] string Password,
    [property: StringLength(30)] string? StudentId);
public record LoginRequest([property: Required, EmailAddress] string Email, [property: Required] string Password);
public record CreateComplaintRequest(
    [property: Required, RegularExpression("^(CAFETERIA|LIBRARY|LAB_IT|ACADEMIC)$")] string Category,
    [property: Required, StringLength(120, MinimumLength = 5)] string Title,
    [property: Required, StringLength(3000, MinimumLength = 10)] string Description,
    [property: StringLength(120)] string? SubIssue,
    [property: RegularExpression("^(LOW|MEDIUM|HIGH)$")] string? Priority,
    [property: StringLength(120)] string? Location,
    [property: MaxLength(3)] string[]? ImageUrls,
    bool AnonymousToStaff = false);
public record StatusRequest(
    [property: Required, RegularExpression("^(PENDING|IN_PROGRESS|RESOLVED|REJECTED)$")] string Status,
    [property: StringLength(2000)] string? Remark,
    [property: Required] Guid? RowVersion);
public record CommentRequest([property: Required, StringLength(2000, MinimumLength = 1)] string Body);
public record FeedbackRequest([property: Range(1, 5)] int Rating, [property: StringLength(500)] string? Comment);
public record UploadRequest([property: Required, RegularExpression("^image/(jpeg|png|webp)$")] string ContentType,
    [property: Range(1, S3Uploads.MaxBytes)] long? FileSize = null);

public class ValidationFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        foreach (var arg in context.Arguments.Where(x => x is not null && x.GetType().Namespace == typeof(RegisterRequest).Namespace))
        {
            var failures = new List<ValidationResult>();
            if (!Validator.TryValidateObject(arg!, new ValidationContext(arg!), failures, true))
                throw new ApiError(422, "VALIDATION_FAILED", "Check the highlighted fields.", failures
                    .SelectMany(x => x.MemberNames.DefaultIfEmpty("body").Select(n => (n, x.ErrorMessage)))
                    .GroupBy(x => x.n).ToDictionary(g => char.ToLowerInvariant(g.Key[0]) + g.Key[1..], g => g.First().ErrorMessage ?? "Invalid value"));
        }
        return await next(context);
    }
}
public class ApiError(int status, string code, string message, Dictionary<string, string>? fields = null) : Exception(message)
{
    public int Status { get; } = status;
    public string Code { get; } = code;
    public Dictionary<string, string>? Fields { get; } = fields;
    public static ApiError Forbidden() => new(403, "FORBIDDEN", "You do not have access to this resource.");
    public static ApiError Invalid(string message) => new(422, "VALIDATION_FAILED", message);
}
