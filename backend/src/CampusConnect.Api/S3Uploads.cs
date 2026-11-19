using System.Text.RegularExpressions;
using Amazon;
using Amazon.S3;
using Amazon.S3.Model;

namespace CampusConnect.Api;

public sealed record ObjectInfo(long Bytes, string? ContentType);

/// <summary>Minimal storage seam so the upload policy can be tested without AWS.</summary>
public interface IObjectStore
{
    string PresignPut(string bucket, string region, string key, string contentType, TimeSpan lifetime);
    /// <returns>null when the object does not exist.</returns>
    Task<ObjectInfo?> Head(string bucket, string region, string key, CancellationToken cancellationToken);
}

/// <summary>Uses the default AWS credential chain (EC2 instance role in production; AWS_* env vars locally).</summary>
public sealed class S3ObjectStore : IObjectStore, IDisposable
{
    private readonly Dictionary<string, AmazonS3Client> clients = [];
    private AmazonS3Client Client(string region)
    {
        lock (clients)
        {
            if (!clients.TryGetValue(region, out var client)) clients[region] = client = new AmazonS3Client(RegionEndpoint.GetBySystemName(region));
            return client;
        }
    }
    public string PresignPut(string bucket, string region, string key, string contentType, TimeSpan lifetime) =>
        Client(region).GetPreSignedURL(new GetPreSignedUrlRequest
        {
            BucketName = bucket, Key = key, Verb = HttpVerb.PUT, ContentType = contentType,
            Expires = DateTime.UtcNow.Add(lifetime), Protocol = Protocol.HTTPS
        });
    public async Task<ObjectInfo?> Head(string bucket, string region, string key, CancellationToken cancellationToken)
    {
        try
        {
            var meta = await Client(region).GetObjectMetadataAsync(bucket, key, cancellationToken);
            return new ObjectInfo(meta.ContentLength, meta.Headers.ContentType);
        }
        catch (AmazonS3Exception e) when (e.StatusCode == System.Net.HttpStatusCode.NotFound) { return null; }
    }
    public void Dispose() { foreach (var c in clients.Values) c.Dispose(); }
}

public sealed class S3Uploads(IObjectStore store, IConfiguration configuration)
{
    public const int MaxBytes = 5 * 1024 * 1024;
    private static readonly Dictionary<string, string> Extensions = new() { ["image/jpeg"] = "jpg", ["image/png"] = "png", ["image/webp"] = "webp" };
    private (string Bucket, string Region) Settings()
    {
        var bucket = configuration["AWS_S3_BUCKET"]; var region = configuration["AWS_REGION"];
        // Dots would break the virtual-hosted TLS certificate, so they are not accepted.
        if (string.IsNullOrWhiteSpace(bucket) || !Regex.IsMatch(bucket, @"^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$")
            || string.IsNullOrWhiteSpace(region) || !Regex.IsMatch(region, @"^[a-z]{2}(-[a-z]+)+-[0-9]$"))
            throw new ApiError(503, "INTERNAL", "Image upload service is not configured.");
        return (bucket, region);
    }
    private static string Host(string bucket, string region) => $"{bucket}.s3.{region}.amazonaws.com";

    public object Sign(UploadRequest request, User user)
    {
        Scope.Student(user);
        var (bucket, region) = Settings();
        if (!Extensions.TryGetValue(request.ContentType, out var extension)) throw ApiError.Invalid("Unsupported image format.");
        if (request.FileSize is <= 0 or > MaxBytes) throw ApiError.Invalid("Images must contain between 1 byte and 5 MiB.");
        var key = $"campusconnect/{user.Id}/{Guid.NewGuid():N}.{extension}";
        // The Content-Type is part of the signature, so the client must send exactly the value declared here.
        // S3 cannot cap a presigned PUT's size, so the real size is verified (HeadObject) when the image is attached.
        var uploadUrl = store.PresignPut(bucket, region, key, request.ContentType, TimeSpan.FromMinutes(5));
        return new
        {
            uploadUrl, method = "PUT", headers = new Dictionary<string, string> { ["Content-Type"] = request.ContentType },
            fields = new Dictionary<string, string>(), publicUrl = $"https://{Host(bucket, region)}/{key}", maxFileSize = MaxBytes
        };
    }

    public async Task Validate(string[] urls, User user, CancellationToken cancellationToken = default)
    {
        if (urls.Length == 0) return;
        var (bucket, region) = Settings();
        var pattern = new Regex(@"^/(campusconnect/" + Regex.Escape(user.Id) + @"/[0-9a-f]{32}\.(jpg|png|webp))$");
        var keys = urls.Select(url =>
        {
            if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != "https" || !uri.IsDefaultPort || uri.UserInfo.Length != 0
                || uri.Query.Length != 0 || uri.Fragment.Length != 0 || !string.Equals(uri.Host, Host(bucket, region), StringComparison.OrdinalIgnoreCase))
                throw ApiError.Invalid("Images must use this application's S3 HTTPS upload URL.");
            var match = pattern.Match(uri.AbsolutePath);
            if (!match.Success) throw ApiError.Invalid("Use an image uploaded for your account through this application.");
            return (Key: match.Groups[1].Value, Extension: match.Groups[2].Value);
        }).ToArray();
        foreach (var (key, extension) in keys)
        {
            ObjectInfo? info;
            try { info = await store.Head(bucket, region, key, cancellationToken); }
            catch (Exception e) when (e is Amazon.Runtime.AmazonServiceException or HttpRequestException or TaskCanceledException)
            { throw new ApiError(503, "INTERNAL", "Image verification is temporarily unavailable."); }
            if (info is null) throw ApiError.Invalid("An image has not been uploaded.");
            if (info.Bytes is < 1 or > MaxBytes || info.ContentType is null || !Extensions.TryGetValue(info.ContentType, out var actual) || actual != extension)
                throw ApiError.Invalid("Images must be JPEG, PNG or WebP and at most 5 MiB.");
        }
    }
}
