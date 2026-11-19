using System.Net;
using System.Text.Json;
using CampusConnect.Api;
using Microsoft.Extensions.Configuration;

namespace CampusConnect.Tests;
public class UploadPolicyTests
{
    private static readonly User Student = new() { Id = "user-student", Role = Roles.Student };
    private const string Url = "https://res.cloudinary.com/test-cloud/image/upload/campusconnect/user-student/proof";
    private static CloudinaryUploads Service(HttpMessageHandler handler) => new(new HttpClient(handler),
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["CLOUDINARY_CLOUD_NAME"] = "test-cloud", ["CLOUDINARY_API_KEY"] = "fake-key", ["CLOUDINARY_API_SECRET"] = "fake-secret" }).Build());
    [Theory]
    [InlineData("https://evil.example/file.jpg")]
    [InlineData("http://res.cloudinary.com/test-cloud/image/upload/campusconnect/user-student/proof")]
    [InlineData("https://res.cloudinary.com/other-cloud/image/upload/campusconnect/user-student/proof")]
    [InlineData("https://res.cloudinary.com/test-cloud/image/upload/campusconnect/other-student/proof")]
    [InlineData("https://res.cloudinary.com/test-cloud/image/fetch/https://evil.example/file.jpg")]
    [InlineData("https://res.cloudinary.com/test-cloud/image/upload/campusconnect/user-student/proof?x=1")]
    public async Task Foreign_or_unissued_image_urls_are_rejected_without_fetching_them(string url)
    {
        var handler = new ResourceHandler(100, "jpg");
        var error = await Assert.ThrowsAsync<ApiError>(() => Service(handler).Validate([url], Student));
        Assert.Equal(422, error.Status); Assert.Equal(0, handler.Calls);
    }
    [Theory]
    [InlineData(5242880, "jpg", true)]
    [InlineData(5242881, "jpg", false)]
    [InlineData(0, "jpg", false)]
    [InlineData(100, "gif", false)]
    public async Task Attachment_checks_actual_cloudinary_bytes_and_format(long bytes, string format, bool accepted)
    {
        var handler = new ResourceHandler(bytes, format);
        if (accepted) await Service(handler).Validate([Url], Student);
        else Assert.Equal(422, (await Assert.ThrowsAsync<ApiError>(() => Service(handler).Validate([Url], Student))).Status);
        Assert.Equal(1, handler.Calls);
    }
    [Theory]
    [InlineData(0)]
    [InlineData(5242881)]
    public void Oversize_or_empty_declared_upload_size_is_rejected(long bytes)
    {
        var error = Assert.Throws<ApiError>(() => Service(new ResourceHandler(1, "jpg")).Sign(new UploadRequest("image/jpeg", bytes), Student));
        Assert.Equal(422, error.Status);
    }
    private sealed class ResourceHandler(long bytes, string format) : HttpMessageHandler
    {
        public int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            Assert.Equal("api.cloudinary.com", request.RequestUri!.Host);
            Assert.Equal("/v1_1/test-cloud/resources/image/upload/campusconnect/user-student/proof", request.RequestUri.AbsolutePath);
            Assert.Equal("Basic", request.Headers.Authorization!.Scheme);
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(JsonSerializer.Serialize(new { public_id = "campusconnect/user-student/proof", bytes, format })) });
        }
    }
}
