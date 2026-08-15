using Events.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Events.Api.Controllers;

[ApiController]
[Route("api")]
public class HealthController : ControllerBase
{
    [HttpGet("healthz")]
    public IActionResult HealthCheck() =>
        Ok(new
        {
            status = "ok",
            timestamp = DateTimeOffset.UtcNow,
            buildNumber = BuildInfo.ReadBuildNumber(),
        });
}
