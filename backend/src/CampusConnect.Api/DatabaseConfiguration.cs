using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace CampusConnect.Api;

public static class DatabaseConfiguration
{
    public static string RequireConnection(IConfiguration configuration)
    {
        var value = configuration.GetConnectionString("DefaultConnection");
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException("ConnectionStrings__DefaultConnection is required. Supply a SQL Server connection string through configuration.");
        try { _ = new SqlConnectionStringBuilder(value); }
        catch (ArgumentException) { throw new InvalidOperationException("ConnectionStrings__DefaultConnection is not a valid SQL Server connection string."); }
        return value;
    }
}

public sealed class AppDbFactory : IDesignTimeDbContextFactory<AppDb>
{
    public AppDb CreateDbContext(string[] args)
    {
        var configuration = new ConfigurationBuilder().AddEnvironmentVariables().Build();
        return new AppDb(new DbContextOptionsBuilder<AppDb>().UseSqlServer(DatabaseConfiguration.RequireConnection(configuration)).Options);
    }
}
