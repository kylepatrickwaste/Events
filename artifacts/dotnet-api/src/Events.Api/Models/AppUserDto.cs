using System.Text.Json.Serialization;

namespace Events.Api.Models;

/// <summary>
/// A row from the <c>AppUsers</c> table. Users are created on first contact
/// rather than provisioned ahead of time, so every field except the Active
/// Directory login is nullable until somebody fills it in.
/// </summary>
public record AppUserDto
{
    public required int Id { get; init; }

    /// <summary>The Windows / AD login, e.g. <c>WCI\kyle.patrick</c>.</summary>
    public required string ActiveDirectoryName { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FriendlyName { get; init; }

    /// <summary>
    /// District <c>Number</c> (not <c>Id</c>) so the choice survives the
    /// re-seed that runs on every API start — identity columns are reassigned
    /// there, district numbers are not.
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? HomeDistrictNumber { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Role { get; init; }

    /// <summary>
    /// Deactivated users keep their row and their audit history; they are just
    /// not expected back. Nothing enforces this at sign-in yet — the API has no
    /// gate of its own, it trusts IIS — so treat it as a roster flag.
    /// </summary>
    public bool Active { get; init; } = true;

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public DateTimeOffset? DateLastSeen { get; init; }
}

/// <summary>
/// Response shape for <c>GET /api/login-name</c>, mirroring the
/// <c>LoginName</c> schema in <c>lib/api-spec/openapi.yaml</c>.
/// </summary>
public record LoginNameDto
{
    /// <summary>
    /// What the UI displays: the friendly name when we have one, otherwise the
    /// raw AD login. Never empty — resolution always falls through to a value.
    /// </summary>
    public required string UserName { get; init; }

    public required string ActiveDirectoryName { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? FriendlyName { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? HomeDistrictNumber { get; init; }

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Role { get; init; }
}

/// <summary>Request body for <c>PUT /api/home-district</c>.</summary>
public record SetHomeDistrictRequest
{
    /// <summary>
    /// District <c>Number</c> to pin, or <c>null</c> to clear it and go back to
    /// landing on the district picker.
    /// </summary>
    public string? DistrictNumber { get; init; }
}

/// <summary>
/// Request body for <c>PUT /api/profile</c>: the two things a user is allowed
/// to change about themselves, saved together.
/// </summary>
public record UpdateProfileRequest
{
    /// <summary>
    /// Preferred display name. Blank or omitted clears it, which makes the app
    /// fall back to showing the raw AD login.
    /// </summary>
    public string? FriendlyName { get; init; }

    /// <summary>
    /// District <c>Number</c> (e.g. <c>2010</c>) to pin, or blank/omitted to
    /// clear the home district. Validated against the districts lookup — an
    /// unknown number is rejected rather than stored.
    /// </summary>
    public string? HomeDistrictNumber { get; init; }
}

/// <summary>
/// Request body for <c>PUT /api/users/{id}</c>: everything an administrator may
/// change about somebody else. Unlike <see cref="UpdateProfileRequest"/> this
/// can also move a user between roles and take them off the active roster.
/// </summary>
public record UpdateUserRequest
{
    /// <summary>Preferred display name; blank clears it.</summary>
    public string? FriendlyName { get; init; }

    /// <summary>District <c>Number</c> to pin, or blank to clear.</summary>
    public string? HomeDistrictNumber { get; init; }

    /// <summary>
    /// <c>Admin</c> or <c>Agent</c>. Omitted leaves the existing role alone,
    /// so a client that does not know about roles cannot blank one out.
    /// </summary>
    public string? Role { get; init; }

    /// <summary>Whether the user is still on the active roster.</summary>
    public bool Active { get; init; } = true;
}
