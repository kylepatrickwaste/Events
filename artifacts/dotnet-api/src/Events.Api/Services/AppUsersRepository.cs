using Dapper;
using Events.Api.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Events.Api.Services;

/// <summary>
/// Reads and writes the <c>AppUsers</c> table. Users are not provisioned ahead
/// of time — the first time a login reaches the API it is inserted.
/// </summary>
public class AppUsersRepository(IDbConnection db)
{
    private const string SelectColumns = """
        SELECT Id, ActiveDirectoryName, FriendlyName, HomeDistrictNumber, Role, DateLastSeen
        FROM AppUsers
        WHERE ActiveDirectoryName = @adName
        """;

    /// <summary>
    /// Records that this login just showed up: inserts the row on first
    /// contact, otherwise just touches <c>DateLastSeen</c>. Returns the row
    /// either way.
    /// </summary>
    public async Task<AppUserDto> EnsureAsync(string activeDirectoryName)
    {
        // UPDATE-then-INSERT rather than MERGE: MERGE on SQL Server has enough
        // documented concurrency and trigger edge cases that it is not worth it
        // for a two-branch upsert.
        const string upsert = """
            UPDATE AppUsers
               SET DateLastSeen = SYSDATETIMEOFFSET()
             WHERE ActiveDirectoryName = @adName;

            IF @@ROWCOUNT = 0
            INSERT INTO AppUsers (ActiveDirectoryName, FriendlyName, Role, DateLastSeen)
            VALUES (@adName, @friendlyName, 'Agent', SYSDATETIMEOFFSET());
            """;

        try
        {
            await db.ExecuteAsync(upsert, new
            {
                adName = activeDirectoryName,
                friendlyName = CurrentUserAccessor.GuessFriendlyName(activeDirectoryName),
            });
        }
        catch (SqlException ex) when (ex.Number is 2601 or 2627)
        {
            // Two first-contact requests raced and the other one inserted first.
            // The unique index did its job; the row we wanted now exists, which
            // is the only thing this method promises.
        }

        var user = await db.QuerySingleOrDefaultAsync<AppUserDto>(
            SelectColumns, new { adName = activeDirectoryName });

        // The upsert above guarantees a row; if it is somehow gone, surface that
        // rather than handing back a hollow object.
        return user ?? throw new InvalidOperationException(
            $"AppUsers row for '{activeDirectoryName}' vanished immediately after upsert.");
    }

    /// <summary>
    /// Pins (or clears, when <paramref name="districtNumber"/> is null) the
    /// user's home district. Returns null when the login has no row yet.
    /// </summary>
    public async Task<AppUserDto?> SetHomeDistrictAsync(string activeDirectoryName, string? districtNumber)
    {
        const string update = """
            UPDATE AppUsers
               SET HomeDistrictNumber = @districtNumber
             WHERE ActiveDirectoryName = @adName;
            """;

        var affected = await db.ExecuteAsync(update, new
        {
            adName = activeDirectoryName,
            districtNumber = string.IsNullOrWhiteSpace(districtNumber) ? null : districtNumber.Trim(),
        });

        if (affected == 0) return null;

        return await db.QuerySingleOrDefaultAsync<AppUserDto>(
            SelectColumns, new { adName = activeDirectoryName });
    }
}
