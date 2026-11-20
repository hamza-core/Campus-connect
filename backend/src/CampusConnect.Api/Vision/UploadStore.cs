namespace CampusConnect.Api.Vision;

/// <summary>Stores complaint photos on local disk (config <c>UPLOADS_DIR</c>). Files are named by an unguessable id.</summary>
public sealed class UploadStore(string directory)
{
    public const int MaxBytes = 5 * 1024 * 1024;
    public const string UrlPrefix = "/api/v1/uploads/";
    private static readonly System.Text.RegularExpressions.Regex IdPattern = new("^[0-9a-f]{32}$");

    public static (string Ext, string Mime)? Detect(ReadOnlySpan<byte> b) =>
        b.Length > 12 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF ? ("jpg", "image/jpeg")
        : b.Length > 12 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 ? ("png", "image/png")
        : b.Length > 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P' ? ("webp", "image/webp")
        : null;

    public static bool IsId(string id) => IdPattern.IsMatch(id);
    public static string UrlFor(string id) => UrlPrefix + id;
    public static string? IdFromUrl(string url) => url.StartsWith(UrlPrefix, StringComparison.Ordinal) && IsId(url[UrlPrefix.Length..]) ? url[UrlPrefix.Length..] : null;

    public async Task<string> Save(byte[] bytes, string ext, CancellationToken ct)
    {
        Directory.CreateDirectory(directory);
        var id = Guid.NewGuid().ToString("N");
        await File.WriteAllBytesAsync(Path.Combine(directory, id + "." + ext), bytes, ct);
        return id;
    }

    public (string Path, string Mime)? Find(string id)
    {
        if (!IsId(id) || !Directory.Exists(directory)) return null;
        foreach (var (ext, mime) in new[] { ("jpg", "image/jpeg"), ("png", "image/png"), ("webp", "image/webp") })
        {
            var path = Path.Combine(directory, id + "." + ext);
            if (File.Exists(path)) return (path, mime);
        }
        return null;
    }
}
