using System.ComponentModel.DataAnnotations;

// Same namespace as the other request records so ValidationFilter validates it.
namespace CampusConnect.Api;

public record ChatHistoryRequest([property: Required] string Role, [property: Required] string Text);
public record ChatRequest(
    [property: Required, StringLength(1000, MinimumLength = 1)] string Message,
    [property: MaxLength(20)] List<ChatHistoryRequest>? History);
