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
}
