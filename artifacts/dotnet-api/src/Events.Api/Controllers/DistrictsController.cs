using Events.Api.Models;
using Events.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Events.Api.Controllers;

[ApiController]
[Route("api")]
public class DistrictsController(EventsRepository repo, AdminAccess admin) : ControllerBase
{
    [HttpGet("districts")]
    public async Task<IActionResult> ListDistricts() =>
        Ok(await repo.ListDistrictsAsync());

    [HttpGet("districts/{districtId:int}/summary")]
    public async Task<IActionResult> GetSummary(int districtId)
    {
        var summary = await repo.GetDistrictSummaryAsync(districtId);
        return summary is null ? NotFound(new ErrorDto("District not found")) : Ok(summary);
    }

    [HttpGet("districts/{districtId:int}/service-codes")]
    public async Task<IActionResult> ListServiceCodes(int districtId) =>
        Ok(await repo.ListServiceCodesAsync(districtId));

    /// <summary>
    /// The excluded-accounts list is administrators-only. Removing the button
    /// from the header hid the capability; this is what actually withholds it.
    /// </summary>
    private async Task<IActionResult?> RequireAdminAsync()
    {
        var (_, isAdmin) = await admin.ResolveAsync();

        return isAdmin
            ? null
            : StatusCode(StatusCodes.Status403Forbidden,
                new ErrorDto("Administrator access required."));
    }

    [HttpGet("districts/{districtId:int}/account-flags")]
    public async Task<IActionResult> ListAccountFlags(int districtId)
    {
        var failure = await RequireAdminAsync();
        if (failure is not null) return failure;

        return Ok(await repo.ListAccountFlagsAsync(districtId));
    }

    [HttpDelete("account-flags/{flagId:int}")]
    public async Task<IActionResult> DeleteAccountFlag(int flagId)
    {
        var failure = await RequireAdminAsync();
        if (failure is not null) return failure;

        var flag = await repo.DeleteAccountFlagAsync(flagId);
        return flag is null ? NotFound(new ErrorDto("Account flag not found")) : Ok(flag);
    }
}
