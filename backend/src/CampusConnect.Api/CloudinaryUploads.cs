using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace CampusConnect.Api;

public sealed class CloudinaryUploads(HttpClient client, IConfiguration configuration)
{
    public const int MaxBytes = 5 * 1024 * 1024;
    private (string Cloud, string Key, string Secret) Credentials()
    {
        var cloud = configuration["CLOUDINARY_CLOUD_NAME"];
        var key = configuration["CLOUDINARY_API_KEY"];
        var secret = configuration["CLOUDINARY_API_SECRET"];
        if (string.IsNullOrWhiteSpace(cloud) || !Regex.IsMatch(cloud, @"^[a-zA-Z0-9_-]+$") || string.IsNullOrWhiteSpace(key) || string.IsNullOrWhiteSpace(secret))
            throw new ApiError(503, "INTERNAL", "Image upload service is not configured.");
        return (cloud, key, secret);
    }
    public object Sign(UploadRequest request, User user)
    {
        Scope.Student(user);
        var (cloud, key, secret) = Credentials();
        var format = request.ContentType switch { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp", _ => throw ApiError.Invalid("Unsupported image format.") };
        if (request.FileSize is <= 0 or > MaxBytes) throw ApiError.Invalid("Images must contain between 1 byte and 5 MiB.");
        var id = "campusconnect/" + user.Id + "/" + Guid.NewGuid().ToString("N");
        var fields = new SortedDictionary<string, string>(StringComparer.Ordinal)
        {
            ["allowed_formats"] = format, ["overwrite"] = "false", ["public_id"] = id,
            ["timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(System.Globalization.CultureInfo.InvariantCulture)
        };
        var signed = string.Join('&', fields.Select(x => x.Key + "=" + x.Value));
        fields["signature"] = Convert.ToHexStringLower(SHA1.HashData(Encoding.UTF8.GetBytes(signed + secret)));
        fields["api_key"] = key;
        // Cloudinary has no max_file_size upload parameter. Enforce real resource bytes on attachment.
        return new { uploadUrl = $"https://api.cloudinary.com/v1_1/{cloud}/image/upload", fields,
            publicUrl = $"https://res.cloudinary.com/{cloud}/image/upload/{id}", maxFileSize = MaxBytes };
    }
    public async Task Validate(string[] urls, User user)
    {
        if (urls.Length == 0) return;
        var (cloud, key, secret) = Credentials();
        var prefix = $"/{cloud}/image/upload/";
        var folder = "campusconnect/" + user.Id + "/";
        var publicIds = urls.Select(url =>
        {
            if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != "https" || uri.Host != "res.cloudinary.com"
                || !uri.IsDefaultPort || uri.UserInfo.Length != 0 || uri.Query.Length != 0 || uri.Fragment.Length != 0 || !uri.AbsolutePath.StartsWith(prefix, StringComparison.Ordinal))
                throw ApiError.Invalid("Images must use this application's Cloudinary HTTPS upload URL.");
            var path = uri.AbsolutePath[prefix.Length..];
            var match = Regex.Match(path, @"^(?:v[0-9]+/)?(" + Regex.Escape(folder) + @"[a-zA-Z0-9_-]+)(?:\.(?:jpg|jpeg|png|webp))?$");
            if (!match.Success) throw ApiError.Invalid("Use an image uploaded for your account through this application.");
            return match.Groups[1].Value;
        }).ToArray();
        foreach (var id in publicIds)
        {
            var encoded = string.Join('/', id.Split('/').Select(Uri.EscapeDataString));
            using var request = new HttpRequestMessage(HttpMethod.Get, $"https://api.cloudinary.com/v1_1/{cloud}/resources/image/upload/{encoded}");
            request.Headers.Authorization = new AuthenticationHeaderValue("Basic", Convert.ToBase64String(Encoding.UTF8.GetBytes(key + ":" + secret)));
            try
            {
                using var response = await client.SendAsync(request);
                if (response.StatusCode == HttpStatusCode.NotFound) throw ApiError.Invalid("An image has not been uploaded.");
                if (!response.IsSuccessStatusCode) throw new ApiError(503, "INTERNAL", "Image verification is temporarily unavailable.");
                using var resource = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
                var data = resource.RootElement;
                if (!data.TryGetProperty("public_id", out var actualId) || actualId.GetString() != id
                    || !data.TryGetProperty("bytes", out var bytes) || !bytes.TryGetInt64(out var length) || length < 1 || length > MaxBytes
                    || !data.TryGetProperty("format", out var format) || format.GetString() is not ("jpg" or "jpeg" or "png" or "webp"))
                    throw ApiError.Invalid("Images must be JPEG, PNG or WebP and at most 5 MiB.");
            }
            catch (HttpRequestException) { throw new ApiError(503, "INTERNAL", "Image verification is temporarily unavailable."); }
            catch (TaskCanceledException) { throw new ApiError(503, "INTERNAL", "Image verification timed out."); }
            catch (JsonException) { throw new ApiError(503, "INTERNAL", "Image verification is temporarily unavailable."); }
        }
    }
}
