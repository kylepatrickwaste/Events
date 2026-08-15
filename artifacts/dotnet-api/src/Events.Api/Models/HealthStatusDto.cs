using System.Text.Json.Serialization;

namespace Events.Api.Models;

/// <summary>
/// Response shape for <c>GET /api/healthz</c>, mirroring the <c>HealthStatus</c>
/// schema in <c>lib/api-spec/openapi.yaml</c>. Declared explicitly rather than
/// projected from an anonymous object so the wire format stays reviewable
/// against the spec.
/// </summary>
public record HealthStatusDto
{
    public required string Status { get; init; }

    public required DateTimeOffset Timestamp { get; init; }

    /// <summary>
    /// Omitted from the payload entirely when unavailable. The spec declares
    /// <c>buildNumber</c> as an optional string, so emitting an explicit
    /// <c>null</c> would violate the contract the generated TypeScript client
    /// relies on. Program.cs sets <c>DefaultIgnoreCondition</c> to
    /// <c>Never</c> globally, so this per-property override is required.
    /// </summary>
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? BuildNumber { get; init; }
}
