using Events.Api.Models;
using Events.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Events.Api.Controllers;

[ApiController]
[Route("api")]
public class UsersController(
    CurrentUserAccessor currentUser,
    AppUsersRepository users,
    EventsRepository districts) : ControllerBase
{
    /// <summary>
    /// The current-user payload every endpoint here answers with. Friendly name
    /// wins; fall back to the raw login so the header is never blank for
    /// someone who is not in the table yet.
    /// </summary>
    private static LoginNameDto ToLoginName(AppUserDto user, string adName) => new()
    {
        UserName = string.IsNullOrWhiteSpace(user.FriendlyName) ? adName : user.FriendlyName,
        ActiveDirectoryName = adName,
        FriendlyName = user.FriendlyName,
        HomeDistrictNumber = user.HomeDistrictNumber,
        Role = user.Role,
    };

    /// <summary>
    /// Who am I? Resolves the login (appsettings overlay on Replit/Development,
    /// IIS Windows Authentication on the real servers), records the visit, and
    /// returns the name to display plus the user's home district.
    /// </summary>
    [HttpGet("login-name")]
    public async Task<IActionResult> LoginName()
    {
        var adName = currentUser.ActiveDirectoryName;
        var user = await users.EnsureAsync(adName);

        return Ok(ToLoginName(user, adName));
    }

    /// <summary>
    /// Pins the district the app should open straight into, or clears it when
    /// <c>districtNumber</c> is omitted.
    /// </summary>
    [HttpPut("home-district")]
    public async Task<IActionResult> SetHomeDistrict([FromBody] SetHomeDistrictRequest body)
    {
        var adName = currentUser.ActiveDirectoryName;

        // The user may never have hit login-name in this session; make sure the
        // row exists before trying to update it.
        await users.EnsureAsync(adName);

        var user = await users.SetHomeDistrictAsync(adName, body.DistrictNumber);
        if (user is null) return NotFound(new ErrorDto("User not found"));

        return Ok(ToLoginName(user, adName));
    }

    /// <summary>
    /// Saves the current user's own profile — preferred name and home district
    /// together, in one write. Blank values clear the corresponding preference;
    /// a home district number that matches no active district is rejected
    /// rather than stored, so the app can never be pinned to a district it
    /// cannot open.
    /// </summary>
    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest body)
    {
        var adName = currentUser.ActiveDirectoryName;

        var requestedDistrict = body.HomeDistrictNumber?.Trim();
        if (!string.IsNullOrEmpty(requestedDistrict))
        {
            var district = await districts.GetDistrictByNumberAsync(requestedDistrict);
            if (district is null)
            {
                return BadRequest(new ErrorDto($"District number '{requestedDistrict}' was not found."));
            }

            // Store the district's own spelling rather than whatever the user
            // typed, so the header's home-district comparison (an exact string
            // match against the districts list) keeps working.
            requestedDistrict = district.Number;
        }

        // The user may never have hit login-name in this session; make sure the
        // row exists before trying to update it.
        await users.EnsureAsync(adName);

        var user = await users.UpdateProfileAsync(adName, body.FriendlyName, requestedDistrict);
        if (user is null) return NotFound(new ErrorDto("User not found"));

        return Ok(ToLoginName(user, adName));
    }

    // ─── Administration ──────────────────────────────────────────────────────

    private const string AdminRole = "Admin";
    private const string AgentRole = "Agent";

    private static bool IsAdminRole(string? role) =>
        string.Equals(role, AdminRole, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Resolves the caller and refuses anyone who is not an administrator.
    /// Hands back the caller's row on success so the endpoint does not look it
    /// up a second time.
    /// </summary>
    private async Task<(AppUserDto? Caller, IActionResult? Failure)> RequireAdminAsync()
    {
        var caller = await users.EnsureAsync(currentUser.ActiveDirectoryName);
        if (!IsAdminRole(caller.Role))
        {
            return (null, StatusCode(StatusCodes.Status403Forbidden,
                new ErrorDto("Administrator access required.")));
        }

        return (caller, null);
    }

    /// <summary>
    /// The whole roster, for the administration section of the profile dialog.
    /// Unpaged on purpose: this table holds a district's agents, not customers.
    /// </summary>
    [HttpGet("users")]
    public async Task<IActionResult> ListUsers()
    {
        var (_, failure) = await RequireAdminAsync();
        if (failure is not null) return failure;

        return Ok(await users.ListAllAsync());
    }

    /// <summary>
    /// An administrator's edit of somebody else's record: preferred name, home
    /// district, role and active status together, in one write.
    /// </summary>
    [HttpPut("users/{id:int}")]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserRequest body)
    {
        var (caller, failure) = await RequireAdminAsync();
        if (failure is not null) return failure;

        var target = await users.GetByIdAsync(id);
        if (target is null) return NotFound(new ErrorDto("User not found"));

        // An omitted role means "leave it alone", so a client that knows nothing
        // about roles cannot blank one out by round-tripping the record.
        var requested = string.IsNullOrWhiteSpace(body.Role) ? target.Role : body.Role.Trim();
        var role = IsAdminRole(requested) ? AdminRole
            : string.Equals(requested, AgentRole, StringComparison.OrdinalIgnoreCase) ? AgentRole
            : null;

        if (role is null)
        {
            return BadRequest(new ErrorDto($"Role must be '{AdminRole}' or '{AgentRole}'."));
        }

        // The one edit with no way back: an administrator who demotes or
        // deactivates themselves loses the very screen they would need to undo
        // it. Every other change here can be reversed by another administrator.
        if (caller!.Id == target.Id && (role != AdminRole || !body.Active))
        {
            return BadRequest(new ErrorDto("You cannot remove your own administrator access."));
        }

        var requestedDistrict = body.HomeDistrictNumber?.Trim();
        if (!string.IsNullOrEmpty(requestedDistrict))
        {
            var district = await districts.GetDistrictByNumberAsync(requestedDistrict);
            if (district is null)
            {
                return BadRequest(new ErrorDto($"District number '{requestedDistrict}' was not found."));
            }

            // Store the district's own spelling, not whatever was typed.
            requestedDistrict = district.Number;
        }

        var updated = await users.AdminUpdateAsync(
            id, body.FriendlyName, requestedDistrict, role, body.Active);

        if (updated is null) return NotFound(new ErrorDto("User not found"));

        return Ok(updated);
    }
}
