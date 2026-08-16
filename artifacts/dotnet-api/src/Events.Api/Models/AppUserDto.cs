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
