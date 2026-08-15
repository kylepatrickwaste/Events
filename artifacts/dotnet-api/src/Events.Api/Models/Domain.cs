using System.Text.Json;

namespace Events.Api.Models;

// ─── DB row types (Dapper maps to these) ─────────────────────────────────────

public record DbDistrict(
    int Id, string Number, string Name, string? Region,
    bool Active, int EventsCount);

public record DbEventType(int Id, string Name, bool Active);
public record DbEventSource(int Id, string Name, bool Active);

public record DbServiceCode(
    int Id, int DistrictId, string Code, string Description,
    decimal Amount, bool Active);

public record DbAccountFlag(
    int Id, int DistrictId, string AccountNumber,
    string Flag, string CreatedBy, DateTimeOffset DateCreated);

public class DbRouteEvent
{
    public int Id { get; init; }
    public int DistrictId { get; init; }
    public int EventTypeId { get; init; }
    public int EventSourceId { get; init; }
    public string? ExternalId { get; init; }
    public DateTimeOffset DateOccurred { get; init; }
    public string Vehicle { get; init; } = "";
    public string Route { get; init; } = "";
    public double Latitude { get; init; }
    public double Longitude { get; init; }
    public string Address { get; init; } = "";
    public string CustomerName { get; init; } = "";
    public string AccountNumber { get; init; } = "";
    public string? BillArea { get; init; }
    public string? BinSerialNumber { get; init; }
    public string? Lob { get; init; }
    public string? RmoStatus { get; init; }
    public string? Details { get; init; }
    public string? Stop { get; init; }
    public string? WorkOrderNumber { get; init; }
    public string? TabletNotes { get; init; }
    public decimal? Quantity { get; init; }
    public string? ImageUrl { get; init; }
    public string? ImageUrlsJson { get; init; }  // stored as JSON string
    public string? Severity { get; init; }
    public DateTimeOffset? CustomerSince { get; init; }
    public int EventStatus { get; init; }
    public DateTimeOffset? DateClosed { get; init; }
    public string? ClosedBy { get; init; }
    public string? CustomerRoutesJson { get; init; }

    public List<string> ImageUrls =>
        string.IsNullOrEmpty(ImageUrlsJson)
            ? []
            : JsonSerializer.Deserialize<List<string>>(ImageUrlsJson) ?? [];

    public List<string> AllImages()
    {
        var list = new List<string>();
        if (!string.IsNullOrEmpty(ImageUrl)) list.Add(ImageUrl);
        list.AddRange(ImageUrls);
        return list.Distinct().ToList();
    }
}

public class DbEventAction
{
    public int Id { get; init; }
    public int RouteEventId { get; init; }
    public string ActionType { get; init; } = "";
    public bool IsFinal { get; init; }
    public string? Notes { get; init; }
    public string? CloseReason { get; init; }
    public int? ServiceCodeId { get; init; }
    public decimal? ChargeAmount { get; init; }
    public decimal? ChargeQuantity { get; init; }
    public string? BilledStatementNumber { get; init; }
    public string? PaymentStatus { get; init; }
    public decimal? BilledAmount { get; init; }
    public string CreatedBy { get; init; } = "";
    public DateTimeOffset DateCreated { get; init; }
}

// ─── API Response DTOs ────────────────────────────────────────────────────────

public record DistrictDto(
    int Id, string Number, string Name, string? Region, int EventsCount);

public record EventTypeDto(int Id, string Name);

public record ServiceCodeDto(
    int Id, int DistrictId, string Code, string Description, decimal Amount);

public record AccountFlagDto(
    int Id, int DistrictId, string AccountNumber,
    string Flag, string CreatedBy, string DateCreated);

public record DistrictSummaryDto(
    int DistrictId,
    int OpenCount,
    int ClosedCount,
    decimal ChargedToday,
    decimal TotalChargedAmount,
    List<EventTypeSummaryDto> ByEventType);

public record EventTypeSummaryDto(
    int EventTypeId, string EventTypeName, int OpenCount);

public record RouteEventListItemDto
{
    public int Id { get; init; }
    public int DistrictId { get; init; }
    public int EventTypeId { get; init; }
    public string EventTypeName { get; init; } = "";
    public string EventSourceName { get; init; } = "";
    public string DateOccurred { get; init; } = "";
    public string Vehicle { get; init; } = "";
    public string Route { get; init; } = "";
    public string CustomerName { get; init; } = "";
    public string AccountNumber { get; init; } = "";
    public string Address { get; init; } = "";
    public decimal? Quantity { get; init; }
    public string? BinSerialNumber { get; init; }
    public string? Lob { get; init; }
    public string? Stop { get; init; }
    public string? WorkOrderNumber { get; init; }
    public string? TabletNotes { get; init; }
    public decimal? ChargedAmount { get; init; }
    public int PrevChargeCount { get; init; }
    public decimal PrevChargeTotal { get; init; }
    public string? ImageUrl { get; init; }
    public List<string> ImageUrls { get; init; } = [];
    public string? Severity { get; init; }
    public int EventStatus { get; init; }
    public string? DateClosed { get; init; }
    public string? ClosedBy { get; init; }
}

public record EventActionDto(
    int Id, int RouteEventId, string ActionType, bool IsFinal,
    string? Notes, string? CloseReason, int? ServiceCodeId,
    decimal? ChargeAmount, decimal? ChargeQuantity,
    string? PaymentStatus, string CreatedBy, string DateCreated);

public record NearbyEventDto(
    int Id, string? ImageUrl, string DateOccurred, int SecondsOffset,
    int EventStatus, string Status, int DistanceMeters,
    bool IsSuggestedDuplicate, string EventSourceName,
    string Address, string CustomerName, string AccountNumber,
    string? BinSerialNumber, string Vehicle);

public record ChargeWindowDto(
    int Days, int EventsCount, int ChargedCount, decimal ChargedAmount,
    int RefundedCount, decimal RefundedAmount, decimal NetPaid);

public record LastChargeDto(
    int Id, string DateCreated, decimal Amount, string? PaymentStatus);

public record EventStatisticsDto(
    int? TenureMonths, string? CustomerSince, string? LastChargeDate,
    List<ChargeWindowDto> Windows);

public record RouteEventDetailDto : RouteEventListItemDto
{
    public string? ExternalId { get; init; }
    public string? BillArea { get; init; }
    public string? RmoStatus { get; init; }
    public string? Details { get; init; }
    public double? Latitude { get; init; }
    public double? Longitude { get; init; }
    public object? Routes { get; init; }
    public List<EventActionDto> Actions { get; init; } = [];
    public EventStatisticsDto? Statistics { get; init; }
    public List<NearbyEventDto> NearbyEvents { get; init; } = [];
    public List<LastChargeDto> LastCharges { get; init; } = [];
    public ShareLinksDto? ShareLinks { get; init; }
}

public record ShareLinksDto(string Event, string Photo, string Source);

public record ErrorDto(string Error);

// ─── Request bodies ───────────────────────────────────────────────────────────

public record AddNoteRequest(string Notes);

public record ChargeEventRequest(
    int ServiceCodeId,
    decimal Amount,
    decimal Quantity,
    bool? KeepOpen,
    List<int>? DuplicateEventIds);

public record EmailEventRequest(
    string ToType,
    string To,
    string Subject,
    string? Body);

public record CloseEventRequest(
    string CloseReason,
    string? Notes,
    List<int>? DuplicateEventIds);

public record BulkCloseRequest(
    List<int> EventIds,
    string CloseReason,
    string? Notes);

public record BulkCloseResponse(int ClosedCount, int SkippedCount);
