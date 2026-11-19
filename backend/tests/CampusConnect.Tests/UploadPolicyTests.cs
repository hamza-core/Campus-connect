using CampusConnect.Api;
using Microsoft.Extensions.Configuration;

namespace CampusConnect.Tests;
public class UploadPolicyTests
{
    private static readonly User Student = new() { Id = "user-student", Role = Roles.Student };
    private const string Key = "campusconnect/user-student/0123456789abcdef0123456789abcdef.jpg";
    private const string Url = "https://test-bucket.s3.eu-north-1.amazonaws.com/" + Key;
    private static S3Uploads Service(FakeStore store) => new(store,
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["AWS_S3_BUCKET"] = "test-bucket", ["AWS_REGION"] = "eu-north-1" }).Build());

    [Theory]
    [InlineData("https://evil.example/file.jpg")]
    [InlineData("http://test-bucket.s3.eu-north-1.amazonaws.com/" + Key)]
    [InlineData("https://other-bucket.s3.eu-north-1.amazonaws.com/" + Key)]
    [InlineData("https://test-bucket.s3.us-east-1.amazonaws.com/" + Key)]
    [InlineData("https://test-bucket.s3.eu-north-1.amazonaws.com/campusconnect/other-student/0123456789abcdef0123456789abcdef.jpg")]
    [InlineData("https://test-bucket.s3.eu-north-1.amazonaws.com/campusconnect/user-student/not-a-guid.jpg")]
    [InlineData("https://test-bucket.s3.eu-north-1.amazonaws.com/campusconnect/user-student/0123456789abcdef0123456789abcdef.gif")]
    [InlineData("https://test-bucket.s3.eu-north-1.amazonaws.com/" + Key + "?X-Amz-Signature=x")]
    [InlineData("https://user:pw@test-bucket.s3.eu-north-1.amazonaws.com/" + Key)]
    public async Task Foreign_or_unissued_image_urls_are_rejected_without_calling_S3(string url)
    {
        var store = new FakeStore(100, "image/jpeg");
        var error = await Assert.ThrowsAsync<ApiError>(() => Service(store).Validate([url], Student));
        Assert.Equal(422, error.Status); Assert.Equal(0, store.HeadCalls);
    }

    [Theory]
    [InlineData(5242880, "image/jpeg", true)]
    [InlineData(5242881, "image/jpeg", false)]
    [InlineData(0, "image/jpeg", false)]
    [InlineData(100, "image/gif", false)]
    [InlineData(100, "image/png", false)] // content type must match the .jpg key
    [InlineData(100, null, false)]
    public async Task Attachment_checks_actual_object_bytes_and_content_type(long bytes, string? contentType, bool accepted)
    {
        var store = new FakeStore(bytes, contentType);
        if (accepted) await Service(store).Validate([Url], Student);
        else Assert.Equal(422, (await Assert.ThrowsAsync<ApiError>(() => Service(store).Validate([Url], Student))).Status);
        Assert.Equal(1, store.HeadCalls);
    }

    [Fact]
    public async Task Missing_object_is_rejected()
    {
        var error = await Assert.ThrowsAsync<ApiError>(() => Service(new FakeStore(null, null)).Validate([Url], Student));
        Assert.Equal(422, error.Status);
    }

    [Fact]
    public async Task Storage_outage_fails_closed_with_503()
    {
        var error = await Assert.ThrowsAsync<ApiError>(() => Service(new FakeStore(1, "image/jpeg") { Throw = true }).Validate([Url], Student));
        Assert.Equal(503, error.Status);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(5242881)]
    public void Oversize_or_empty_declared_upload_size_is_rejected(long bytes)
    {
        var error = Assert.Throws<ApiError>(() => Service(new FakeStore(1, "image/jpeg")).Sign(new UploadRequest("image/jpeg", bytes), Student));
        Assert.Equal(422, error.Status);
    }

    [Fact]
    public void Missing_bucket_configuration_is_reported_as_unavailable_without_leaking_details()
    {
        var empty = new S3Uploads(new FakeStore(1, "image/jpeg"), new ConfigurationBuilder().Build());
        var error = Assert.Throws<ApiError>(() => empty.Sign(new UploadRequest("image/jpeg", 10), Student));
        Assert.Equal(503, error.Status);
    }

    [Fact]
    public void Dotted_bucket_names_are_rejected()
    {
        var dotted = new S3Uploads(new FakeStore(1, "image/jpeg"), new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?> { ["AWS_S3_BUCKET"] = "my.bucket", ["AWS_REGION"] = "eu-north-1" }).Build());
        Assert.Equal(503, Assert.Throws<ApiError>(() => dotted.Sign(new UploadRequest("image/jpeg", 10), Student)).Status);
    }
}

public sealed class FakeStore(long? bytes, string? contentType) : IObjectStore
{
    public int HeadCalls { get; private set; }
    public bool Throw { get; set; }
    public string PresignPut(string bucket, string region, string key, string contentType, TimeSpan lifetime) =>
        $"https://{bucket}.s3.{region}.amazonaws.com/{key}?X-Amz-Signature=fake";
    public Task<ObjectInfo?> Head(string bucket, string region, string key, CancellationToken cancellationToken)
    {
        HeadCalls++;
        if (Throw) throw new HttpRequestException("S3 unavailable");
        return Task.FromResult(bytes is null ? null : new ObjectInfo(bytes.Value, contentType));
    }
}
