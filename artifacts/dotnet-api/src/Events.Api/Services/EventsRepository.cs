using Dapper;
using Events.Api.Models;
using Microsoft.Extensions.Options;
using System.Data;
using System.Text.Json;

namespace Events.Api.Services;

public class AppSettings
{
    public string CurrentUser { get; set; } = "Kyle.Patrick";
    public double NearbyRadiusMeters { get; set; } = 300;
    public int NearbyWindowMinutes { get; set; } = 60;
    public int NearbyMaxResults { get; set; } = 10;
    public double SuggestedDuplicateRadiusMeters { get; set; } = 75;
    public int SuggestedDuplicateWindowMinutes { get; set; } = 5;
}

public class EventsRepository(IDbConnection db, IConfiguration cfg)
{
    private readonly AppSettings _settings = cfg.GetSection("AppSettings").Get<AppSettings>() ?? new();
    private string CurrentUser => _settings.CurrentUser;
    private const string ContractCloseReason = "Contract - No Overages";

    // ─── Districts ────────────────────────────────────────────────────────────

    public async Task<List<DistrictDto>> ListDistrictsAsync()
    {
        // Columns match DistrictDto member-for-member, so Dapper materialises
        // the DTO directly — no dynamic row plumbing needed.
        const string sql = """
            SELECT d.Id, d.Number, d.Name, d.Region,
                   COUNT(re.Id) AS EventsCount
            FROM Districts d
            LEFT JOIN RouteEvents re ON re.DistrictId = d.Id
            WHERE d.Active = 1
            GROUP BY d.Id, d.Number, d.Name, d.Region
            ORDER BY d.Number
            """;
        return (await db.QueryAsync<DistrictDto>(sql)).ToList();
    }

    public async Task<DbDistrict?> GetDistrictAsync(int districtId)
    {
        // EventsCount is not a column on Districts — this lookup only needs the
        // district row itself, so the count is selected as a literal zero.
        const string sql = "SELECT Id, Number, Name, Region, Active, 0 AS EventsCount FROM Districts WHERE Id = @id";
        return await db.QueryFirstOrDefaultAsync<DbDistrict>(sql, new { id = districtId });
    }

    public async Task<DistrictSummaryDto?> GetDistrictSummaryAsync(int districtId)
    {
        var district = await GetDistrictAsync(districtId);
        if (district is null) return null;

        // SQL Server rejects a subquery inside an aggregate function, so the
        // contract_no_overages exclusion is hoisted into WHERE. It was applied
        // identically to both branches, so the counts are unchanged.
        const string countsSql = """
            SELECT
                SUM(CASE WHEN re.EventStatus = 0 THEN 1 ELSE 0 END) AS OpenCount,
                SUM(CASE WHEN re.EventStatus = 1 THEN 1 ELSE 0 END) AS ClosedCount
            FROM RouteEvents re
            WHERE re.DistrictId = @districtId
              AND NOT EXISTS (
                SELECT 1 FROM AccountFlags af
                WHERE af.DistrictId = re.DistrictId AND af.AccountNumber = re.AccountNumber AND af.Flag = 'contract_no_overages'
              )
            """;
        var counts = await db.QueryFirstAsync<dynamic>(countsSql, new { districtId });

        const string chargesSql = """
            SELECT
                SUM(CASE WHEN ea.ActionType = 'charge' AND CAST(ea.DateCreated AS DATE) = CAST(GETUTCDATE() AS DATE) THEN 1 ELSE 0 END) AS ChargedToday,
                ISNULL(SUM(CASE WHEN ea.ActionType = 'charge' THEN ea.ChargeAmount * ISNULL(ea.ChargeQuantity, 1) ELSE 0 END), 0) AS TotalCharged
            FROM EventActions ea
            INNER JOIN RouteEvents re ON re.Id = ea.RouteEventId
            WHERE re.DistrictId = @districtId
              AND NOT EXISTS (
                SELECT 1 FROM AccountFlags af
                WHERE af.DistrictId = re.DistrictId AND af.AccountNumber = re.AccountNumber AND af.Flag = 'contract_no_overages'
              )
            """;
        var charges = await db.QueryFirstAsync<dynamic>(chargesSql, new { districtId });

        const string byTypeSql = """
            SELECT et.Id AS EventTypeId, et.Name AS EventTypeName,
                   SUM(CASE WHEN re.EventStatus = 0 THEN 1 ELSE 0 END) AS OpenCount
            FROM RouteEvents re
            INNER JOIN EventTypes et ON et.Id = re.EventTypeId
            WHERE re.DistrictId = @districtId
              AND NOT EXISTS (
                SELECT 1 FROM AccountFlags af
                WHERE af.DistrictId = re.DistrictId AND af.AccountNumber = re.AccountNumber AND af.Flag = 'contract_no_overages'
              )
            GROUP BY et.Id, et.Name
            ORDER BY et.Name
            """;
        var byType = (await db.QueryAsync<dynamic>(byTypeSql, new { districtId })).ToList();

        return new DistrictSummaryDto(
            DistrictId: districtId,
            OpenCount: (int)(counts.OpenCount ?? 0),
            ClosedCount: (int)(counts.ClosedCount ?? 0),
            ChargedToday: (decimal)(charges.ChargedToday ?? 0),
            TotalChargedAmount: (decimal)(charges.TotalCharged ?? 0),
            ByEventType: byType.Select(r => new EventTypeSummaryDto(
                (int)r.EventTypeId, (string)r.EventTypeName, (int)r.OpenCount)).ToList()
        );
    }

    public async Task<List<ServiceCodeDto>> ListServiceCodesAsync(int districtId)
    {
        const string sql = """
            SELECT Id, DistrictId, Code, Description, Amount FROM ServiceCodes
            WHERE DistrictId = @districtId AND Active = 1
            ORDER BY Code
            """;
        return (await db.QueryAsync<ServiceCodeDto>(sql, new { districtId })).ToList();
    }

    public async Task<List<AccountFlagDto>> ListAccountFlagsAsync(int districtId)
    {
        const string sql = """
            SELECT Id, DistrictId, AccountNumber, Flag, CreatedBy, DateCreated
            FROM AccountFlags WHERE DistrictId = @districtId
            ORDER BY DateCreated DESC
            """;
        var rows = await db.QueryAsync<dynamic>(sql, new { districtId });
        return rows.Select(SerializeFlag).ToList();
    }

    public async Task<AccountFlagDto?> DeleteAccountFlagAsync(int flagId)
    {
        const string sql = """
            DELETE FROM AccountFlags
            OUTPUT DELETED.Id, DELETED.DistrictId, DELETED.AccountNumber,
                   DELETED.Flag, DELETED.CreatedBy, DELETED.DateCreated
            WHERE Id = @flagId
            """;
        var row = await db.QueryFirstOrDefaultAsync<dynamic>(sql, new { flagId });
        return row is null ? null : SerializeFlag(row);
    }

    private static AccountFlagDto SerializeFlag(dynamic r) =>
        new((int)r.Id, (int)r.DistrictId, (string)r.AccountNumber,
            (string)r.Flag, (string)r.CreatedBy,
            ((DateTimeOffset)r.DateCreated).ToString("O"));

    // ─── Event Types ──────────────────────────────────────────────────────────

    public async Task<List<EventTypeDto>> ListEventTypesAsync()
    {
        const string sql = "SELECT Id, Name FROM EventTypes WHERE Active = 1 ORDER BY Name";
        return (await db.QueryAsync<EventTypeDto>(sql)).ToList();
    }

    // ─── Events list ──────────────────────────────────────────────────────────

    public async Task<List<RouteEventListItemDto>> ListEventsAsync(
        int districtId, string? status, int? eventTypeId,
        string? severity, string? search)
    {
        const string notFlagged =
            "NOT EXISTS (SELECT 1 FROM AccountFlags af" +
            " WHERE af.DistrictId = re.DistrictId AND af.AccountNumber = re.AccountNumber AND af.Flag = 'contract_no_overages')";

        var conditions = new List<string>
        {
            "re.DistrictId = @districtId",
            notFlagged
        };

        if (status == "open" || status is null)
            conditions.Add("re.EventStatus = 0");
        else if (status == "closed")
            conditions.Add("re.EventStatus = 1");

        if (eventTypeId.HasValue)
            conditions.Add("re.EventTypeId = @eventTypeId");

        if (!string.IsNullOrEmpty(severity) && severity != "all")
            conditions.Add("LOWER(re.Severity) = @severity");

        if (!string.IsNullOrEmpty(search))
            conditions.Add("(re.CustomerName LIKE @search OR re.Address LIKE @search" +
                " OR re.AccountNumber LIKE @search OR re.Route LIKE @search OR re.Vehicle LIKE @search)");

        var where = string.Join(" AND ", conditions);
        var sql = $"""
            SELECT re.*,
                   et.Name AS EventTypeName,
                   es.Name AS EventSourceName,
                   (SELECT SUM(ea.ChargeAmount * ISNULL(ea.ChargeQuantity, 1))
                    FROM EventActions ea
                    WHERE ea.RouteEventId = re.Id AND ea.ActionType = 'charge') AS ChargedAmount,
                   (SELECT COUNT(*)
                    FROM EventActions ea
                    JOIN RouteEvents re2 ON re2.Id = ea.RouteEventId
                    WHERE re2.AccountNumber = re.AccountNumber
                      AND ea.ActionType = 'charge'
                      AND re2.DateOccurred < re.DateOccurred) AS PrevChargeCount,
                   (SELECT ISNULL(SUM(ea.ChargeAmount * ISNULL(ea.ChargeQuantity, 1)), 0)
                    FROM EventActions ea
                    JOIN RouteEvents re2 ON re2.Id = ea.RouteEventId
                    WHERE re2.AccountNumber = re.AccountNumber
                      AND ea.ActionType = 'charge'
                      AND re2.DateOccurred < re.DateOccurred) AS PrevChargeTotal
            FROM RouteEvents re
            INNER JOIN EventTypes et ON et.Id = re.EventTypeId
            INNER JOIN EventSources es ON es.Id = re.EventSourceId
            WHERE {where}
            ORDER BY re.DateOccurred DESC
            """;

        var p = new DynamicParameters();
        p.Add("districtId", districtId);
        if (eventTypeId.HasValue) p.Add("eventTypeId", eventTypeId.Value);
        if (!string.IsNullOrEmpty(severity) && severity != "all") p.Add("severity", severity.ToLower());
        if (!string.IsNullOrEmpty(search)) p.Add("search", $"%{search}%");

        var rows = await db.QueryAsync<dynamic>(sql, p);
        return rows.Select(r => (RouteEventListItemDto)MapListItem((dynamic)r)).ToList();
    }

    private static RouteEventListItemDto MapListItem(dynamic r)
    {
        // ImageUrls is stored as a JSON array string; ImageUrl is the primary photo.
        var images = ParseJsonArray((string?)r.ImageUrls);
        var primaryImage = (string?)r.ImageUrl;
        var allImages = new List<string>();
        if (!string.IsNullOrEmpty(primaryImage)) allImages.Add(primaryImage);
        allImages.AddRange(images);
        allImages = allImages.Distinct().ToList();

        decimal? chgAmt = null;
        try { chgAmt = r.ChargedAmount is not null ? (decimal?)Convert.ToDecimal(r.ChargedAmount) : null; } catch { }

        return new RouteEventListItemDto
        {
            Id = (int)r.Id,
            DistrictId = (int)r.DistrictId,
            EventTypeId = (int)r.EventTypeId,
            EventTypeName = (string)(r.EventTypeName ?? ""),
            EventSourceName = (string)(r.EventSourceName ?? ""),
            DateOccurred = ((DateTimeOffset)r.DateOccurred).ToString("O"),
            Vehicle = (string)(r.Vehicle ?? ""),
            Route = (string)(r.Route ?? ""),
            CustomerName = (string)(r.CustomerName ?? ""),
            AccountNumber = (string)(r.AccountNumber ?? ""),
            Address = (string)(r.Address ?? ""),
            Quantity = r.Quantity is not null ? (decimal?)Convert.ToDecimal(r.Quantity) : null,
            BinSerialNumber = (string?)r.BinSerialNumber,
            Lob = (string?)r.Lob,
            Stop = (string?)r.Stop,
            WorkOrderNumber = (string?)r.WorkOrderNumber,
            TabletNotes = (string?)r.TabletNotes,
            ChargedAmount = chgAmt,
            PrevChargeCount = r.PrevChargeCount is not null ? Convert.ToInt32(r.PrevChargeCount) : 0,
            PrevChargeTotal = r.PrevChargeTotal is not null ? Convert.ToDecimal(r.PrevChargeTotal) : 0,
            ImageUrl = primaryImage,
            ImageUrls = allImages,
            Severity = (string?)r.Severity,
            EventStatus = (int)r.EventStatus,
            DateClosed = r.DateClosed is not null ? ((DateTimeOffset)r.DateClosed).ToString("O") : null,
            ClosedBy = (string?)r.ClosedBy,
        };
    }

    private static List<string> ParseJsonArray(string? json)
    {
        if (string.IsNullOrEmpty(json)) return [];
        try { return JsonSerializer.Deserialize<List<string>>(json) ?? []; }
        catch { return []; }
    }

    // ─── Event detail ─────────────────────────────────────────────────────────

    public async Task<RouteEventDetailDto?> GetEventDetailAsync(int eventId)
    {
        const string eventSql = """
            SELECT re.*,
                   et.Name AS EventTypeName, es.Name AS EventSourceName,
                   d.Number AS DistrictNumber
            FROM RouteEvents re
            INNER JOIN EventTypes et ON et.Id = re.EventTypeId
            INNER JOIN EventSources es ON es.Id = re.EventSourceId
            INNER JOIN Districts d ON d.Id = re.DistrictId
            WHERE re.Id = @eventId
            """;
        var row = await db.QueryFirstOrDefaultAsync<dynamic>(eventSql, new { eventId });
        if (row is null) return null;

        const string actionsSql = """
            SELECT * FROM EventActions WHERE RouteEventId = @eventId ORDER BY DateCreated DESC
            """;
        var actionRows = await db.QueryAsync<dynamic>(actionsSql, new { eventId });
        var actions = actionRows.Select(SerializeAction).ToList();

        // Statistics
        var now = DateTimeOffset.UtcNow;
        var cutoff90 = now.AddDays(-90);
        var accountNumber = (string)row.AccountNumber;
        var districtId = (int)row.DistrictId;

        const string accountChargesSql = """
            SELECT ea.Id, ea.DateCreated, ea.ChargeAmount, ea.ChargeQuantity, ea.PaymentStatus
            FROM EventActions ea
            INNER JOIN RouteEvents re ON re.Id = ea.RouteEventId
            WHERE re.AccountNumber = @accountNumber AND re.DistrictId = @districtId
              AND ea.ActionType = 'charge' AND ea.DateCreated >= @cutoff90
            ORDER BY ea.DateCreated DESC
            """;
        var accountCharges = (await db.QueryAsync<dynamic>(
            accountChargesSql, new { accountNumber, districtId, cutoff90 })).ToList();

        const string recentChargesSql = """
            SELECT TOP 3 ea.Id, ea.DateCreated, ea.ChargeAmount, ea.ChargeQuantity, ea.PaymentStatus
            FROM EventActions ea
            INNER JOIN RouteEvents re ON re.Id = ea.RouteEventId
            WHERE re.AccountNumber = @accountNumber AND re.DistrictId = @districtId
              AND ea.ActionType = 'charge'
            ORDER BY ea.DateCreated DESC
            """;
        var recentCharges = (await db.QueryAsync<dynamic>(
            recentChargesSql, new { accountNumber, districtId })).ToList();

        const string eventDatesSql = """
            SELECT DateOccurred FROM RouteEvents
            WHERE AccountNumber = @accountNumber AND DistrictId = @districtId AND DateOccurred >= @cutoff90
            """;
        var eventDates = (await db.QueryAsync<DateTimeOffset>(
            eventDatesSql, new { accountNumber, districtId, cutoff90 })).ToList();

        var windows = new[] { 30, 60, 90 }.Select(days =>
        {
            var cutoff = now.AddDays(-days);
            var inWindow = accountCharges.Where(c => (DateTimeOffset)c.DateCreated >= cutoff).ToList();
            var paid = inWindow.Where(c => (string?)c.PaymentStatus == "PAID").ToList();
            var refunded = inWindow.Where(c => (string?)c.PaymentStatus == "REFUNDED").ToList();
            // Enumerable.Sum must not be used over dynamic rows: the lambda's
            // return type is dynamic, so the overload is picked at runtime and
            // binds to the int version, throwing on a decimal. Accumulate into
            // an explicitly typed local instead.
            static decimal Sum(IEnumerable<dynamic> rows)
            {
                decimal total = 0m;
                foreach (var c in rows)
                {
                    decimal amount = Convert.ToDecimal(c.ChargeAmount ?? 0m);
                    decimal quantity = Convert.ToDecimal(c.ChargeQuantity ?? 1m);
                    total += amount * quantity;
                }
                return total;
            }
            return new ChargeWindowDto(
                Days: days,
                EventsCount: eventDates.Count(d => d >= cutoff),
                ChargedCount: inWindow.Count,
                ChargedAmount: Sum(inWindow),
                RefundedCount: refunded.Count,
                RefundedAmount: Sum(refunded),
                NetPaid: Sum(paid) - Sum(refunded));
        }).ToList();

        DateTimeOffset? customerSince = row.CustomerSince is not null ? (DateTimeOffset?)row.CustomerSince : null;
        int? tenureMonths = customerSince.HasValue ? MonthsBetween(customerSince.Value, now) : null;
        string? lastChargeDate = recentCharges.Count > 0
            ? ((DateTimeOffset)recentCharges[0].DateCreated).ToString("O") : null;

        var statistics = new EventStatisticsDto(
            TenureMonths: tenureMonths,
            CustomerSince: customerSince?.ToString("O"),
            LastChargeDate: lastChargeDate,
            Windows: windows);

        var lastCharges = recentCharges.Select(c => new LastChargeDto(
            Id: (int)c.Id,
            DateCreated: ((DateTimeOffset)c.DateCreated).ToString("O"),
            Amount: Convert.ToDecimal(c.ChargeAmount ?? 0m) * Convert.ToDecimal(c.ChargeQuantity ?? 1m),
            PaymentStatus: (string?)c.PaymentStatus)).ToList();

        // Nearby events
        var anchorLat = (double)row.Latitude;
        var anchorLon = (double)row.Longitude;
        var anchorDate = (DateTimeOffset)row.DateOccurred;
        var windowMs = TimeSpan.FromMinutes(_settings.NearbyWindowMinutes);
        var dateFrom = anchorDate - windowMs;
        var dateTo = anchorDate + windowMs;
        var distId = (int)row.DistrictId;
        var eId = (int)row.Id;

        var nearbyRows = await QueryNearbyRowsAsync(eId, distId, anchorLat, anchorLon, dateFrom, dateTo);

        var nearbyIds = nearbyRows.Select(n => n.Id).ToList();
        HashSet<int> chargedNearbyIds = [];
        if (nearbyIds.Count > 0)
        {
            var chargeActSql = $"""
                SELECT RouteEventId FROM EventActions
                WHERE RouteEventId IN ({string.Join(",", nearbyIds)}) AND ActionType = 'charge'
                """;
            var chargeIds = await db.QueryAsync<int>(chargeActSql);
            chargedNearbyIds = [.. chargeIds];
        }

        var nearbyEvents = nearbyRows.Select(n =>
        {
            var offsetMs = (n.DateOccurred - anchorDate).TotalSeconds;
            var isSuggestedDup = n.EventStatus == 0
                && n.DistanceMeters <= _settings.SuggestedDuplicateRadiusMeters
                && Math.Abs(offsetMs) <= _settings.SuggestedDuplicateWindowMinutes * 60;
            string status = n.EventStatus == 0 ? "Open"
                : chargedNearbyIds.Contains(n.Id) ? "Charged" : "Dismissed";
            return new NearbyEventDto(
                Id: n.Id, ImageUrl: n.ImageUrl,
                DateOccurred: ((DateTimeOffset)n.DateOccurred).ToString("O"),
                SecondsOffset: (int)offsetMs,
                EventStatus: n.EventStatus, Status: status,
                DistanceMeters: (int)Math.Round(n.DistanceMeters),
                IsSuggestedDuplicate: isSuggestedDup,
                EventSourceName: n.EventSourceName ?? "",
                Address: n.Address ?? "", CustomerName: n.CustomerName ?? "",
                AccountNumber: n.AccountNumber ?? "",
                BinSerialNumber: n.BinSerialNumber,
                Vehicle: n.Vehicle ?? "");
        }).ToList();

        var districtNumber = (string)row.DistrictNumber;
        var externalId = (string?)row.ExternalId;
        var baseItem = MapListItem(row);

        return new RouteEventDetailDto
        {
            Id = baseItem.Id, DistrictId = baseItem.DistrictId,
            EventTypeId = baseItem.EventTypeId, EventTypeName = baseItem.EventTypeName,
            EventSourceName = baseItem.EventSourceName, DateOccurred = baseItem.DateOccurred,
            Vehicle = baseItem.Vehicle, Route = baseItem.Route,
            CustomerName = baseItem.CustomerName, AccountNumber = baseItem.AccountNumber,
            Address = baseItem.Address, Quantity = baseItem.Quantity,
            BinSerialNumber = baseItem.BinSerialNumber, Lob = baseItem.Lob,
            Stop = baseItem.Stop, WorkOrderNumber = baseItem.WorkOrderNumber,
            TabletNotes = baseItem.TabletNotes, ChargedAmount = baseItem.ChargedAmount,
            PrevChargeCount = baseItem.PrevChargeCount, PrevChargeTotal = baseItem.PrevChargeTotal,
            ImageUrl = baseItem.ImageUrl, ImageUrls = baseItem.ImageUrls,
            Severity = baseItem.Severity, EventStatus = baseItem.EventStatus,
            DateClosed = baseItem.DateClosed, ClosedBy = baseItem.ClosedBy,
            ExternalId = externalId,
            BillArea = (string?)row.BillArea,
            RmoStatus = (string?)row.RmoStatus,
            Details = (string?)row.Details,
            Latitude = (double)row.Latitude,
            Longitude = (double)row.Longitude,
            Routes = row.CustomerRoutes is not null
                ? JsonSerializer.Deserialize<object>((string)row.CustomerRoutes)
                : null,
            Actions = actions,
            Statistics = statistics,
            NearbyEvents = nearbyEvents,
            LastCharges = lastCharges,
            ShareLinks = new ShareLinksDto(
                Event: $"https://events.wcnx.org/{districtNumber}/events/{eId}",
                Photo: $"https://events.wcnx.org/{districtNumber}/imageproxy?url={Uri.EscapeDataString(row.ImageUrl ?? "")}",
                Source: $"https://monitor.wastevision.ai/Media/Details?mediaId={externalId ?? eId.ToString()}")
        };
    }

    private async Task<List<dynamic>> QueryNearbyRowsAsync(
        int excludeId, int districtId, double anchorLat, double anchorLon,
        DateTimeOffset dateFrom, DateTimeOffset dateTo)
    {
        // The radius filter is a row-level predicate, not an aggregate one, so it
        // cannot live in HAVING (SQL Server rejects the non-grouped lat/lon
        // columns). Computing the distance once in a CTE lets the outer query
        // filter on the alias in WHERE.
        var sql = $"""
            WITH Nearby AS (
                SELECT
                    re.Id, re.ImageUrl, re.DateOccurred, re.EventStatus,
                    re.Address, re.CustomerName, re.AccountNumber, re.BinSerialNumber, re.Vehicle,
                    es.Name AS EventSourceName,
                    (2 * 6371000 * ATN2(
                        SQRT(
                            POWER(SIN(RADIANS(re.Latitude - @anchorLat) / 2), 2)
                            + COS(RADIANS(@anchorLat)) * COS(RADIANS(re.Latitude))
                            * POWER(SIN(RADIANS(re.Longitude - @anchorLon) / 2), 2)
                        ),
                        SQRT(1 - (
                            POWER(SIN(RADIANS(re.Latitude - @anchorLat) / 2), 2)
                            + COS(RADIANS(@anchorLat)) * COS(RADIANS(re.Latitude))
                            * POWER(SIN(RADIANS(re.Longitude - @anchorLon) / 2), 2)
                        ))
                    )) AS DistanceMeters
                FROM RouteEvents re
                INNER JOIN EventSources es ON es.Id = re.EventSourceId
                WHERE re.DistrictId = @districtId
                  AND re.Id <> @excludeId
                  AND re.DateOccurred >= @dateFrom
                  AND re.DateOccurred <= @dateTo
            )
            SELECT TOP {_settings.NearbyMaxResults}
                Id, ImageUrl, DateOccurred, EventStatus,
                Address, CustomerName, AccountNumber, BinSerialNumber, Vehicle,
                EventSourceName, DistanceMeters
            FROM Nearby
            WHERE DistanceMeters <= @radiusMeters
            ORDER BY DistanceMeters ASC, DateOccurred ASC
            """;
        var result = await db.QueryAsync<dynamic>(sql, new
        {
            anchorLat, anchorLon, districtId, excludeId,
            dateFrom, dateTo, radiusMeters = _settings.NearbyRadiusMeters
        });
        return result.ToList();
    }

    // ─── Actions ──────────────────────────────────────────────────────────────

    public async Task<EventActionDto?> AddNoteAsync(int eventId, string notes)
    {
        var evt = await GetOpenEventAsync(eventId);
        if (evt is null) return null;

        const string sql = """
            INSERT INTO EventActions (RouteEventId, ActionType, IsFinal, Notes, CreatedBy, DateCreated)
            OUTPUT INSERTED.*
            VALUES (@routeEventId, 'note', 0, @notes, @createdBy, GETUTCDATE())
            """;
        var row = await db.QueryFirstOrDefaultAsync<dynamic>(sql,
            new { routeEventId = eventId, notes, createdBy = CurrentUser });
        return row is null ? null : SerializeAction(row);
    }

    public async Task<(EventActionDto? Action, string? Error)> ChargeEventAsync(
        int eventId, int serviceCodeId, decimal amount, decimal quantity,
        bool keepOpen, List<int> duplicateEventIds)
    {
        var evt = await GetOpenEventAsync(eventId);
        if (evt is null) return (null, "Event not found");

        // Validate duplicates are nearby
        if (duplicateEventIds.Count > 0)
        {
            var anchorLat = (double)evt.Latitude;
            var anchorLon = (double)evt.Longitude;
            var anchorDate = (DateTimeOffset)evt.DateOccurred;
            var windowMs = TimeSpan.FromMinutes(_settings.NearbyWindowMinutes);
            var nearby = await QueryNearbyRowsAsync(
                eventId, (int)evt.DistrictId, anchorLat, anchorLon,
                anchorDate - windowMs, anchorDate + windowMs);
            var nearbySet = nearby.Select(n => (int)n.Id).ToHashSet();
            if (!duplicateEventIds.All(id => nearbySet.Contains(id)))
                return (null, "duplicateEventIds must be nearby overages of this event");
        }

        if (db.State != ConnectionState.Open) db.Open();
        using var tx = db.BeginTransaction();
        try
        {
            // Check contract flag
            const string flagSql = """
                SELECT TOP 1 Id FROM AccountFlags
                WHERE DistrictId = @districtId AND AccountNumber = @accountNumber AND Flag = 'contract_no_overages'
                """;
            var flag = await db.QueryFirstOrDefaultAsync<int?>(flagSql,
                new { districtId = (int)evt.DistrictId, accountNumber = (string)evt.AccountNumber }, tx);
            if (flag.HasValue) return (null, "flagged");

            // Re-check open status with lock
            const string lockSql = "SELECT EventStatus FROM RouteEvents WITH (UPDLOCK, HOLDLOCK) WHERE Id = @id";
            var currentStatus = await db.QueryFirstOrDefaultAsync<int?>(lockSql, new { id = eventId }, tx);
            if (currentStatus is null || currentStatus != 0) return (null, "closed");

            const string insertSql = """
                INSERT INTO EventActions
                    (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, CreatedBy, DateCreated)
                OUTPUT INSERTED.*
                VALUES (@routeEventId, 'charge', @isFinal, @serviceCodeId, @chargeAmount, @chargeQuantity, @createdBy, GETUTCDATE())
                """;
            var inserted = await db.QueryFirstAsync<dynamic>(insertSql, new
            {
                routeEventId = eventId, isFinal = !keepOpen,
                serviceCodeId, chargeAmount = amount, chargeQuantity = quantity,
                createdBy = CurrentUser
            }, tx);

            if (!keepOpen)
            {
                await db.ExecuteAsync(
                    "UPDATE RouteEvents SET EventStatus=1, DateClosed=GETUTCDATE(), ClosedBy=@by WHERE Id=@id",
                    new { by = CurrentUser, id = eventId }, tx);
            }

            if (duplicateEventIds.Count > 0)
                await CloseDuplicatesAsync(duplicateEventIds, $"Duplicate", $"Dismissed as duplicate of charged event #{eventId}", tx);

            tx.Commit();
            return (SerializeAction(inserted), null);
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }

    public async Task<EventActionDto?> AddEmailAsync(int eventId, string toType, string to, string subject, string? body)
    {
        var evt = await GetOpenEventAsync(eventId);
        if (evt is null) return null;
        var notes = $"{toType}: {to} — {subject}{(body is not null ? $" — {body}" : "")}";
        const string sql = """
            INSERT INTO EventActions (RouteEventId, ActionType, IsFinal, Notes, CreatedBy, DateCreated)
            OUTPUT INSERTED.*
            VALUES (@routeEventId, 'email', 0, @notes, @createdBy, GETUTCDATE())
            """;
        var row = await db.QueryFirstOrDefaultAsync<dynamic>(sql,
            new { routeEventId = eventId, notes, createdBy = CurrentUser });
        return row is null ? null : SerializeAction(row);
    }

    public async Task<(EventActionDto? Action, string? Error)> CloseEventAsync(
        int eventId, string closeReason, string? notes, List<int> duplicateIds)
    {
        var evt = await GetOpenEventAsync(eventId);
        if (evt is null) return (null, "Event not found");

        if (duplicateIds.Count > 0)
        {
            var anchorLat = (double)evt.Latitude;
            var anchorLon = (double)evt.Longitude;
            var anchorDate = (DateTimeOffset)evt.DateOccurred;
            var windowMs = TimeSpan.FromMinutes(_settings.NearbyWindowMinutes);
            var nearby = await QueryNearbyRowsAsync(
                eventId, (int)evt.DistrictId, anchorLat, anchorLon,
                anchorDate - windowMs, anchorDate + windowMs);
            var nearbySet = nearby.Select(n => (int)n.Id).ToHashSet();
            if (!duplicateIds.All(id => nearbySet.Contains(id)))
                return (null, "duplicateEventIds must be nearby overages of this event");
        }

        if (db.State != ConnectionState.Open) db.Open();
        using var tx = db.BeginTransaction();
        try
        {
            const string closeSql = """
                UPDATE RouteEvents SET EventStatus=1, DateClosed=GETUTCDATE(), ClosedBy=@by
                OUTPUT INSERTED.Id
                WHERE Id=@id AND EventStatus=0
                """;
            var closedId = await db.QueryFirstOrDefaultAsync<int?>(closeSql,
                new { by = CurrentUser, id = eventId }, tx);
            if (!closedId.HasValue) { tx.Rollback(); return (null, "closed"); }

            const string actionSql = """
                INSERT INTO EventActions (RouteEventId, ActionType, IsFinal, CloseReason, Notes, CreatedBy, DateCreated)
                OUTPUT INSERTED.*
                VALUES (@routeEventId, 'close', 1, @closeReason, @notes, @createdBy, GETUTCDATE())
                """;
            var action = await db.QueryFirstAsync<dynamic>(actionSql, new
            {
                routeEventId = eventId, closeReason, notes, createdBy = CurrentUser
            }, tx);

            if (closeReason == ContractCloseReason)
                await FlagAccountAsync((int)evt.DistrictId, (string)evt.AccountNumber, tx);

            if (duplicateIds.Count > 0)
                await CloseDuplicatesAsync(duplicateIds, "Duplicate", $"Dismissed as duplicate of closed event #{eventId}", tx);

            tx.Commit();
            return (SerializeAction(action), null);
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }

    public async Task<BulkCloseResponse> BulkCloseAsync(List<int> eventIds, string closeReason, string? notes)
    {
        var uniqueIds = eventIds.Distinct().ToList();
        if (uniqueIds.Count == 0) return new BulkCloseResponse(0, 0);

        var inClause = string.Join(",", uniqueIds);
        var targetsSql = $"SELECT Id, DistrictId, AccountNumber FROM RouteEvents WHERE Id IN ({inClause})";
        var targets = (await db.QueryAsync<dynamic>(targetsSql)).ToList();
        var districts = targets.Select(t => (int)t.DistrictId).Distinct().ToList();
        if (districts.Count > 1) throw new InvalidOperationException("All events must belong to the same district");

        if (db.State != ConnectionState.Open) db.Open();
        using var tx = db.BeginTransaction();
        try
        {
            var closeSql = $"""
                UPDATE RouteEvents SET EventStatus=1, DateClosed=GETUTCDATE(), ClosedBy=@by
                OUTPUT INSERTED.Id
                WHERE Id IN ({inClause}) AND EventStatus=0
                """;
            var closedIds = (await db.QueryAsync<int>(closeSql, new { by = CurrentUser }, tx)).ToList();

            if (closedIds.Count > 0)
            {
                var actionValues = string.Join(",", closedIds.Select((id, i) =>
                    $"(@rid{i}, 'close', 1, @reason, @notes, @by, GETUTCDATE())"));
                var p = new DynamicParameters();
                for (int i = 0; i < closedIds.Count; i++) p.Add($"rid{i}", closedIds[i]);
                p.Add("reason", closeReason); p.Add("notes", notes); p.Add("by", CurrentUser);
                await db.ExecuteAsync(
                    $"INSERT INTO EventActions (RouteEventId,ActionType,IsFinal,CloseReason,Notes,CreatedBy,DateCreated) VALUES {actionValues}", p, tx);

                if (closeReason == ContractCloseReason)
                {
                    var closedSet = closedIds.ToHashSet();
                    var toFlag = targets
                        .Where(t => closedSet.Contains((int)t.Id))
                        .GroupBy(t => $"{t.DistrictId}:{t.AccountNumber}")
                        .Select(g => g.First())
                        .ToList();
                    foreach (var t in toFlag)
                        await FlagAccountAsync((int)t.DistrictId, (string)t.AccountNumber, tx);
                }
            }
            tx.Commit();
            return new BulkCloseResponse(closedIds.Count, uniqueIds.Count - closedIds.Count);
        }
        catch { tx.Rollback(); throw; }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private async Task<dynamic?> GetOpenEventAsync(int eventId)
    {
        const string sql = "SELECT * FROM RouteEvents WHERE Id = @id";
        return await db.QueryFirstOrDefaultAsync<dynamic>(sql, new { id = eventId });
    }

    private async Task CloseDuplicatesAsync(List<int> ids, string reason, string notes, IDbTransaction tx)
    {
        var inClause = string.Join(",", ids);
        var closeSql = $"""
            UPDATE RouteEvents SET EventStatus=1, DateClosed=GETUTCDATE(), ClosedBy=@by
            OUTPUT INSERTED.Id
            WHERE Id IN ({inClause}) AND EventStatus=0
            """;
        var closedIds = (await db.QueryAsync<int>(closeSql, new { by = CurrentUser }, tx)).ToList();
        if (closedIds.Count > 0)
        {
            var vals = string.Join(",", closedIds.Select((id, i) =>
                $"(@did{i}, 'close', 1, @reason, @notes, @by, GETUTCDATE())"));
            var p = new DynamicParameters();
            for (int i = 0; i < closedIds.Count; i++) p.Add($"did{i}", closedIds[i]);
            p.Add("reason", reason); p.Add("notes", notes); p.Add("by", CurrentUser);
            await db.ExecuteAsync(
                $"INSERT INTO EventActions (RouteEventId,ActionType,IsFinal,CloseReason,Notes,CreatedBy,DateCreated) VALUES {vals}", p, tx);
        }
    }

    private async Task FlagAccountAsync(int districtId, string accountNumber, IDbTransaction tx)
    {
        const string sql = """
            IF NOT EXISTS (
                SELECT 1 FROM AccountFlags WHERE DistrictId=@did AND AccountNumber=@acct AND Flag='contract_no_overages'
            )
            INSERT INTO AccountFlags (DistrictId, AccountNumber, Flag, CreatedBy, DateCreated)
            VALUES (@did, @acct, 'contract_no_overages', @by, GETUTCDATE())
            """;
        await db.ExecuteAsync(sql, new { did = districtId, acct = accountNumber, by = CurrentUser }, tx);
    }

    private static EventActionDto SerializeAction(dynamic a) => new(
        Id: (int)a.Id, RouteEventId: (int)a.RouteEventId,
        ActionType: (string)a.ActionType, IsFinal: (bool)a.IsFinal,
        Notes: (string?)a.Notes, CloseReason: (string?)a.CloseReason,
        ServiceCodeId: (int?)a.ServiceCodeId,
        ChargeAmount: a.ChargeAmount is not null ? (decimal?)Convert.ToDecimal(a.ChargeAmount) : null,
        ChargeQuantity: a.ChargeQuantity is not null ? (decimal?)Convert.ToDecimal(a.ChargeQuantity) : null,
        PaymentStatus: (string?)a.PaymentStatus,
        CreatedBy: (string)a.CreatedBy,
        DateCreated: ((DateTimeOffset)a.DateCreated).ToString("O"));

    private static int MonthsBetween(DateTimeOffset from, DateTimeOffset to) =>
        Math.Max(0, (to.Year - from.Year) * 12 + (to.Month - from.Month));
}
