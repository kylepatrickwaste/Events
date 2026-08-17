using Dapper;
using Microsoft.Data.SqlClient;

namespace Events.Api.Services;

/// <summary>
/// Break-glass administrator promotion. This is the one thing the API still
/// writes at start-up: it is access control, not schema or seed data, and it is
/// the only recovery path that does not need somebody with direct database
/// access. Schema creation and demo data live in the T-SQL scripts under
/// <c>files/</c> and are applied by hand.
/// </summary>
public static class BootstrapAdmins
{
    /// <summary>
    /// Promotes the logins listed under <c>Access:BootstrapAdmins</c> on every
    /// start. Re-applied each time rather than seeded once on purpose: it is the
    /// way back in if the last administrator is ever demoted, and a config edit
    /// plus a restart is all it takes.
    /// </summary>
    public static async Task ApplyAsync(string connectionString, IEnumerable<string> logins)
    {
        var wanted = logins
            .Where(l => !string.IsNullOrWhiteSpace(l))
            .Select(l => l.Trim())
            .ToList();

        if (wanted.Count == 0) return;

        await using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        foreach (var login in wanted)
        {
            // Match a domain-qualified login as well as a bare one: the config
            // says 352271, but IIS hands us WCI\352271 on the real servers and
            // both are the same person.
            // Promote only; deliberately no INSERT. The row is created on first
            // contact under whatever name IIS reports, and inventing a second one
            // here under the bare configured spelling would leave the real caller
            // matched to an Agent row. AdminAccess promotes them on arrival
            // instead, so a login that has never visited needs nothing here.
            await conn.ExecuteAsync(@"
UPDATE AppUsers
   SET Role = 'Admin', Active = 1
 WHERE ActiveDirectoryName = @login
    OR RIGHT(ActiveDirectoryName, LEN(@login) + 1) = '\' + @login;", new { login });
        }
    }
}
