using Microsoft.Data.SqlClient;

namespace CampusConnect.Api;
public static class DatabaseConflicts
{
    public static bool IsRace(Exception error)
    {
        for (Exception? current = error; current is not null; current = current.InnerException)
            if (current is SqlException { Number: 1205 or 2601 or 2627 }) return true;
        return false;
    }
}
