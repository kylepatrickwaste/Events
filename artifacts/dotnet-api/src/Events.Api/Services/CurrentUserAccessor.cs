using System.Globalization;

namespace Events.Api.Services;

/// <summary>
/// Resolves who the current request is acting as. There is always a user — the
/// chain below cannot produce an empty string — because the audit columns
/// (<c>CreatedBy</c>, <c>ClosedBy</c>) are NOT NULL and a blank stamp would be
/// worse than a placeholder.
/// </summary>
public sealed class CurrentUserAccessor(IConfiguration cfg, IHttpContextAccessor http)
{
    private const string Fallback = "Unknown";

    /// <summary>
    /// A <c>UserName</c> key in the active appsettings overlay wins (only the
    /// Replit and Development overlays define it); otherwise the Windows
    /// identity, which IIS Windows Authentication populates on the real
    /// servers; otherwise the legacy single-user setting; otherwise a
    /// placeholder.
    /// </summary>
    public string ActiveDirectoryName
    {
        get
        {
            var configured = cfg["UserName"];
            if (!string.IsNullOrWhiteSpace(configured)) return configured.Trim();

            var windows = http.HttpContext?.User.Identity?.Name;
            if (!string.IsNullOrWhiteSpace(windows)) return windows.Trim();

            var legacy = cfg["AppSettings:CurrentUser"];
            if (!string.IsNullOrWhiteSpace(legacy)) return legacy.Trim();

            return Fallback;
        }
    }

    /// <summary>
    /// Best-effort display name for a login we have never seen before, used to
    /// populate <c>FriendlyName</c> on auto-insert: <c>WCI\kyle.patrick</c>
    /// becomes <c>Kyle Patrick</c>. A human can correct it in the table later.
    /// </summary>
    public static string GuessFriendlyName(string activeDirectoryName)
    {
        // Drop the domain from either DOMAIN\user or user@domain form.
        var bare = activeDirectoryName;
        var slash = bare.LastIndexOf('\\');
        if (slash >= 0) bare = bare[(slash + 1)..];
        var at = bare.IndexOf('@');
        if (at > 0) bare = bare[..at];

        var parts = bare.Split(['.', '_', '-'], StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return activeDirectoryName;

        var titled = parts.Select(p =>
            CultureInfo.InvariantCulture.TextInfo.ToTitleCase(p.ToLowerInvariant()));
        return string.Join(' ', titled);
    }
}
