using Events.Api.Models;
using Events.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Events.Api.Controllers;

[ApiController]
[Route("api")]
public class EventsController(EventsRepository repo) : ControllerBase
{
    [HttpGet("event-types")]
    public async Task<IActionResult> ListEventTypes() =>
        Ok(await repo.ListEventTypesAsync());

    [HttpGet("events")]
    public async Task<IActionResult> ListEvents(
        [FromQuery] int districtId,
        [FromQuery] string? status,
        [FromQuery] int? eventTypeId,
        [FromQuery] string? severity,
        [FromQuery] string? search)
    {
        var events = await repo.ListEventsAsync(districtId, status, eventTypeId, severity, search);
        return Ok(events);
    }

    [HttpGet("events/{eventId:int}")]
    public async Task<IActionResult> GetEvent(int eventId)
    {
        var detail = await repo.GetEventDetailAsync(eventId);
        return detail is null ? NotFound(new ErrorDto("Event not found")) : Ok(detail);
    }

    [HttpPost("events/{eventId:int}/notes")]
    public async Task<IActionResult> AddNote(int eventId, [FromBody] AddNoteRequest req)
    {
        var action = await repo.AddNoteAsync(eventId, req.Notes);
        return action is null ? NotFound(new ErrorDto("Event not found")) : StatusCode(201, action);
    }

    [HttpPost("events/{eventId:int}/charge")]
    public async Task<IActionResult> ChargeEvent(int eventId, [FromBody] ChargeEventRequest req)
    {
        var (action, error) = await repo.ChargeEventAsync(
            eventId, req.ServiceCodeId, req.Amount, req.Quantity,
            req.KeepOpen ?? false, req.DuplicateEventIds ?? []);

        return error switch
        {
            "Event not found" => NotFound(new ErrorDto(error)),
            "flagged" => Conflict(new ErrorDto("Account is under contract; overages cannot be charged")),
            "closed" => Conflict(new ErrorDto("Event is already closed")),
            not null => BadRequest(new ErrorDto(error)),
            _ => StatusCode(201, action)
        };
    }

    [HttpPost("events/{eventId:int}/email")]
    public async Task<IActionResult> EmailEvent(int eventId, [FromBody] EmailEventRequest req)
    {
        var action = await repo.AddEmailAsync(eventId, req.ToType, req.To, req.Subject, req.Body);
        return action is null ? NotFound(new ErrorDto("Event not found")) : StatusCode(201, action);
    }

    [HttpPost("events/{eventId:int}/close")]
    public async Task<IActionResult> CloseEvent(int eventId, [FromBody] CloseEventRequest req)
    {
        var (action, error) = await repo.CloseEventAsync(
            eventId, req.CloseReason, req.Notes, req.DuplicateEventIds ?? []);
        return error switch
        {
            "Event not found" => NotFound(new ErrorDto(error)),
            "closed" => Conflict(new ErrorDto("Event is already closed")),
            not null => BadRequest(new ErrorDto(error)),
            _ => StatusCode(201, action)
        };
    }

    [HttpPost("events/bulk-close")]
    public async Task<IActionResult> BulkClose([FromBody] BulkCloseRequest req)
    {
        try
        {
            var result = await repo.BulkCloseAsync(req.EventIds, req.CloseReason, req.Notes);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ErrorDto(ex.Message));
        }
    }
}
