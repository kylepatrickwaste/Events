using Events.Api.Models;
using Events.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Events.Api.Controllers;

[ApiController]
[Route("api")]
public class UsersController(CurrentUserAccessor currentUser, AppUsersRepository users) : ControllerBase
{
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

        return Ok(new LoginNameDto
        {
            // Friendly name wins; fall back to the raw login so the header is
            // never blank for someone who is not in the table yet.
            UserName = string.IsNullOrWhiteSpace(user.FriendlyName) ? adName : user.FriendlyName,
            ActiveDirectoryName = adName,
            FriendlyName = user.FriendlyName,
            HomeDistrictNumber = user.HomeDistrictNumber,
            Role = user.Role,
        });
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

        return Ok(new LoginNameDto
        {
            UserName = string.IsNullOrWhiteSpace(user.FriendlyName) ? adName : user.FriendlyName,
            ActiveDirectoryName = adName,
            FriendlyName = user.FriendlyName,
            HomeDistrictNumber = user.HomeDistrictNumber,
            Role = user.Role,
        });
    }
}
