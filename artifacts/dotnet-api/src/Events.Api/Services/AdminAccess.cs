using Events.Api.Models;

namespace Events.Api.Services;

/// <summary>
/// Decides whether the caller may use the administrator-only endpoints, and is
/// the only place that answers that question — hiding a button in the client
/// hides a capability, it does not remove it.
/// </summary>
public sealed class AdminAccess(
    IConfiguration cfg,
    CurrentUserAccessor currentUser,
    AppUsersRepository users)
{
    public const string AdminRole = "Admin";
    public const string AgentRole = "Agent";

    public static bool IsAdminRole(string? role) =>
        string.Equals(role, AdminRole, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// The login with any domain stripped: <c>WCI\352271</c>, <c>352271@wcn.com</c>
    /// and <c>352271</c> are all one person, and configuration is written in the
    /// bare form while IIS hands us the qualified one.
    /// </summary>
    private static string BareLogin(string login)
    {
        var bare = login;

        var slash = bare.LastIndexOf('\\');
        if (slash >= 0) bare = bare[(slash + 1)..];

        var at = bare.IndexOf('@');
        if (at > 0) bare = bare[..at];

        return bare.Trim();
    }

    /// <summary>
    /// Whether this login is named in <c>Access:BootstrapAdmins</c>. Read from
    /// configuration on each call rather than cached so an edit to appsettings
    /// takes effect on the next request instead of the next deployment.
    /// </summary>
    private bool IsBootstrapAdmin(string adName)
    {
        var configured = cfg.GetSection("Access:BootstrapAdmins").Get<string[]>() ?? [];
        var bare = BareLogin(adName);

        return configured.Any(login =>
            !string.IsNullOrWhiteSpace(login) &&
            string.Equals(BareLogin(login), bare, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>
    /// Resolves the caller's row, promoting a configured break-glass login that
    /// is not an administrator yet.
    /// </summary>
    /// <remarks>
    /// The promotion matters because the two identities need not agree: the
    /// config says <c>352271</c>, but the row the API creates on first contact
    /// is named whatever IIS reported, e.g. <c>WCI\352271</c>. Promoting here,
    /// against the row that actually exists, means the configured administrator
    /// is an administrator on their very first request — no restart, and no
    /// second row under the other spelling of their name.
    ///
    /// It also closes the lock-out hole: however the <c>Role</c> column ends up,
    /// a login named in configuration is an administrator, so there is always a
    /// way back in without database access.
    /// </remarks>
    public async Task<AppUserDto> ResolveCallerAsync()
    {
        var adName = currentUser.ActiveDirectoryName;
        var caller = await users.EnsureAsync(adName);

        if (!IsAdminRole(caller.Role) && IsBootstrapAdmin(adName))
        {
            caller = await users.SetRoleAsync(caller.Id, AdminRole) ?? caller;
        }

        return caller;
    }

    /// <summary>
    /// The caller's row plus whether they are an administrator, so a controller
    /// can refuse the request and still know who was asking.
    /// </summary>
    public async Task<(AppUserDto Caller, bool IsAdmin)> ResolveAsync()
    {
        var caller = await ResolveCallerAsync();
        return (caller, IsAdminRole(caller.Role));
    }
}
