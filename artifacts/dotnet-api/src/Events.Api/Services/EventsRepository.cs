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
        const string sql = """
            SELECT d.id, d.number, d.name, d.region,
                   COUNT(re.id) AS events_count
            FROM districts d
            LEFT JOIN route_events re ON re.district_id = d.id
            WHERE d.active = 1
            GROUP BY d.id, d.number, d.name, d.region
            ORDER BY d.number
            """;
        var rows = await db.QueryAsync<dynamic>(sql);
        return rows.Select(r => new DistrictDto(
            (int)r.id, (string)r.number, (string)r.name, (string?)r.region, (int)r.events_count
        )).ToList();
    }

    public async Task<DbDistrict?> GetDistrictAsync(int districtId)
    {
        // Alias must match the DbDistrict constructor parameter name exactly:
        // Dapper is not configured with MatchNamesWithUnderscores, so
        // "events_count" would fail to bind to EventsCount.
        const string sql = "SELECT id, number, name, region, active, 0 AS EventsCount FROM districts WHERE id = @id";
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
                SUM(CASE WHEN re.event_status = 0 THEN 1 ELSE 0 END) AS open_count,
                SUM(CASE WHEN re.event_status = 1 THEN 1 ELSE 0 END) AS closed_count
            FROM route_events re
            WHERE re.district_id = @districtId
              AND NOT EXISTS (
                SELECT 1 FROM account_flags af
                WHERE af.district_id = re.district_id AND af.account_number = re.account_number AND af.flag = 'contract_no_overages'
              )
            """;
        var counts = await db.QueryFirstAsync<dynamic>(countsSql, new { districtId });

        const string chargesSql = """
            SELECT
                SUM(CASE WHEN ea.action_type = 'charge' AND CAST(ea.date_created AS DATE) = CAST(GETUTCDATE() AS DATE) THEN 1 ELSE 0 END) AS charged_today,
                ISNULL(SUM(CASE WHEN ea.action_type = 'charge' THEN ea.charge_amount * ISNULL(ea.charge_quantity, 1) ELSE 0 END), 0) AS total_charged
            FROM event_actions ea
            INNER JOIN route_events re ON re.id = ea.route_event_id
            WHERE re.district_id = @districtId
              AND NOT EXISTS (
                SELECT 1 FROM account_flags af
                WHERE af.district_id = re.district_id AND af.account_number = re.account_number AND af.flag = 'contract_no_overages'
              )
            """;
        var charges = await db.QueryFirstAsync<dynamic>(chargesSql, new { districtId });

        const string byTypeSql = """
            SELECT et.id AS event_type_id, et.name AS event_type_name,
                   SUM(CASE WHEN re.event_status = 0 THEN 1 ELSE 0 END) AS open_count
            FROM route_events re
            INNER JOIN event_types et ON et.id = re.event_type_id
            WHERE re.district_id = @districtId
              AND NOT EXISTS (
                SELECT 1 FROM account_flags af
                WHERE af.district_id = re.district_id AND af.account_number = re.account_number AND af.flag = 'contract_no_overages'
              )
            GROUP BY et.id, et.name
            ORDER BY et.name
            """;
        var byType = (await db.QueryAsync<dynamic>(byTypeSql, new { districtId })).ToList();

        return new DistrictSummaryDto(
            DistrictId: districtId,
            OpenCount: (int)(counts.open_count ?? 0),
            ClosedCount: (int)(counts.closed_count ?? 0),
            ChargedToday: (decimal)(charges.charged_today ?? 0),
            TotalChargedAmount: (decimal)(charges.total_charged ?? 0),
            ByEventType: byType.Select(r => new EventTypeSummaryDto(
                (int)r.event_type_id, (string)r.event_type_name, (int)r.open_count)).ToList()
        );
    }

    public async Task<List<ServiceCodeDto>> ListServiceCodesAsync(int districtId)
    {
        const string sql = """
            SELECT id, district_id, code, description, amount FROM service_codes
            WHERE district_id = @districtId AND active = 1
            ORDER BY code
            """;
        var rows = await db.QueryAsync<dynamic>(sql, new { districtId });
        return rows.Select(r => new ServiceCodeDto(
            (int)r.id, (int)r.district_id, (string)r.code, (string)r.description, (decimal)r.amount
        )).ToList();
    }

    public async Task<List<AccountFlagDto>> ListAccountFlagsAsync(int districtId)
    {
        const string sql = """
            SELECT id, district_id, account_number, flag, created_by, date_created
            FROM account_flags WHERE district_id = @districtId
            ORDER BY date_created DESC
            """;
        var rows = await db.QueryAsync<dynamic>(sql, new { districtId });
        return rows.Select(SerializeFlag).ToList();
    }

    public async Task<AccountFlagDto?> DeleteAccountFlagAsync(int flagId)
    {
        const string sql = """
            DELETE FROM account_flags
            OUTPUT DELETED.id, DELETED.district_id, DELETED.account_number,
                   DELETED.flag, DELETED.created_by, DELETED.date_created
            WHERE id = @flagId
            """;
        var row = await db.QueryFirstOrDefaultAsync<dynamic>(sql, new { flagId });
        return row is null ? null : SerializeFlag(row);
    }

    private static AccountFlagDto SerializeFlag(dynamic r) =>
        new((int)r.id, (int)r.district_id, (string)r.account_number,
            (string)r.flag, (string)r.created_by,
            ((DateTimeOffset)r.date_created).ToString("O"));

    // ─── Event Types ──────────────────────────────────────────────────────────

    public async Task<List<EventTypeDto>> ListEventTypesAsync()
    {
        const string sql = "SELECT id, name FROM event_types WHERE active = 1 ORDER BY name";
        var rows = await db.QueryAsync<dynamic>(sql);
        return rows.Select(r => new EventTypeDto((int)r.id, (string)r.name)).ToList();
    }

    // ─── Events list ──────────────────────────────────────────────────────────

    public async Task<List<RouteEventListItemDto>> ListEventsAsync(
        int districtId, string? status, int? eventTypeId,
        string? severity, string? search)
    {
        const string notFlagged =
            "NOT EXISTS (SELECT 1 FROM account_flags af" +
            " WHERE af.district_id = re.district_id AND af.account_number = re.account_number AND af.flag = 'contract_no_overages')";

        var conditions = new List<string>
        {
            "re.district_id = @districtId",
            notFlagged
        };

        if (status == "open" || status is null)
            conditions.Add("re.event_status = 0");
        else if (status == "closed")
            conditions.Add("re.event_status = 1");

        if (eventTypeId.HasValue)
            conditions.Add("re.event_type_id = @eventTypeId");

        if (!string.IsNullOrEmpty(severity) && severity != "all")
            conditions.Add("LOWER(re.severity) = @severity");

        if (!string.IsNullOrEmpty(search))
            conditions.Add("(re.customer_name LIKE @search OR re.address LIKE @search" +
                " OR re.account_number LIKE @search OR re.route LIKE @search OR re.vehicle LIKE @search)");

        var where = string.Join(" AND ", conditions);
        var sql = $"""
            SELECT re.*,
                   re.image_urls AS image_urls_json,
                   et.name AS event_type_name,
                   es.name AS event_source_name,
                   (SELECT SUM(ea.charge_amount * ISNULL(ea.charge_quantity, 1))
                    FROM event_actions ea
                    WHERE ea.route_event_id = re.id AND ea.action_type = 'charge') AS charged_amount,
                   (SELECT COUNT(*)
                    FROM event_actions ea
                    JOIN route_events re2 ON re2.id = ea.route_event_id
                    WHERE re2.account_number = re.account_number
                      AND ea.action_type = 'charge'
                      AND re2.date_occurred < re.date_occurred) AS prev_charge_count,
                   (SELECT ISNULL(SUM(ea.charge_amount * ISNULL(ea.charge_quantity, 1)), 0)
                    FROM event_actions ea
                    JOIN route_events re2 ON re2.id = ea.route_event_id
                    WHERE re2.account_number = re.account_number
                      AND ea.action_type = 'charge'
                      AND re2.date_occurred < re.date_occurred) AS prev_charge_total
            FROM route_events re
            INNER JOIN event_types et ON et.id = re.event_type_id
            INNER JOIN event_sources es ON es.id = re.event_source_id
            WHERE {where}
            ORDER BY re.date_occurred DESC
            """;

        var p = new DynamicParameters();
        p.Add("districtId", districtId);
        if (eventTypeId.HasValue) p.Add("eventTypeId", eventTypeId.Value);
        if (!string.IsNullOrEmpty(severity) && severity != "all") p.Add("severity", severity.ToLower());
        if (!string.IsNullOrEmpty(search)) p.Add("search", $"%{search}%");

        var rows = await db.QueryAsync<dynamic>(sql, p);
        return rows.Select(r => (RouteEventListItemDto)MapListItem((dynamic)r)).ToList();
    }

    private static RouteEventListItemDto MapListItem(dynamic r,
        decimal? chargedAmount = null, int? prevChargeCount = null, decimal? prevChargeTotal = null)
    {
        var images = ParseJsonArray((string?)r.image_urls_json);
        var primaryImage = (string?)r.image_url;
        var allImages = new List<string>();
        if (!string.IsNullOrEmpty(primaryImage)) allImages.Add(primaryImage);
        allImages.AddRange(images);
        allImages = allImages.Distinct().ToList();

        decimal? chgAmt = null;
        try { chgAmt = r.charged_amount is not null ? (decimal?)Convert.ToDecimal(r.charged_amount) : null; } catch { }

        return new RouteEventListItemDto
        {
            Id = (int)r.id,
            DistrictId = (int)r.district_id,
            EventTypeId = (int)r.event_type_id,
            EventTypeName = (string)(r.event_type_name ?? ""),
            EventSourceName = (string)(r.event_source_name ?? ""),
            DateOccurred = ((DateTimeOffset)r.date_occurred).ToString("O"),
            Vehicle = (string)(r.vehicle ?? ""),
            Route = (string)(r.route ?? ""),
            CustomerName = (string)(r.customer_name ?? ""),
            AccountNumber = (string)(r.account_number ?? ""),
            Address = (string)(r.address ?? ""),
            Quantity = r.quantity is not null ? (decimal?)Convert.ToDecimal(r.quantity) : null,
            BinSerialNumber = (string?)r.bin_serial_number,
            Lob = (string?)r.lob,
            Stop = (string?)r.stop,
            WorkOrderNumber = (string?)r.work_order_number,
            TabletNotes = (string?)r.tablet_notes,
            ChargedAmount = chgAmt,
            PrevChargeCount = r.prev_charge_count is not null ? Convert.ToInt32(r.prev_charge_count) : 0,
            PrevChargeTotal = r.prev_charge_total is not null ? Convert.ToDecimal(r.prev_charge_total) : 0,
            ImageUrl = primaryImage,
            ImageUrls = allImages,
            Severity = (string?)r.severity,
            EventStatus = (int)r.event_status,
            DateClosed = r.date_closed is not null ? ((DateTimeOffset)r.date_closed).ToString("O") : null,
            ClosedBy = (string?)r.closed_by,
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
            SELECT re.*, re.image_urls AS image_urls_json,
                   et.name AS event_type_name, es.name AS event_source_name,
                   d.number AS district_number
            FROM route_events re
            INNER JOIN event_types et ON et.id = re.event_type_id
            INNER JOIN event_sources es ON es.id = re.event_source_id
            INNER JOIN districts d ON d.id = re.district_id
            WHERE re.id = @eventId
            """;
        var row = await db.QueryFirstOrDefaultAsync<dynamic>(eventSql, new { eventId });
        if (row is null) return null;

        const string actionsSql = """
            SELECT * FROM event_actions WHERE route_event_id = @eventId ORDER BY date_created DESC
            """;
        var actionRows = await db.QueryAsync<dynamic>(actionsSql, new { eventId });
        var actions = actionRows.Select(SerializeAction).ToList();

        // Statistics
        var now = DateTimeOffset.UtcNow;
        var cutoff90 = now.AddDays(-90);
        var accountNumber = (string)row.account_number;
        var districtId = (int)row.district_id;

        const string accountChargesSql = """
            SELECT ea.id, ea.date_created, ea.charge_amount, ea.charge_quantity, ea.payment_status
            FROM event_actions ea
            INNER JOIN route_events re ON re.id = ea.route_event_id
            WHERE re.account_number = @accountNumber AND re.district_id = @districtId
              AND ea.action_type = 'charge' AND ea.date_created >= @cutoff90
            ORDER BY ea.date_created DESC
            """;
        var accountCharges = (await db.QueryAsync<dynamic>(
            accountChargesSql, new { accountNumber, districtId, cutoff90 })).ToList();

        const string recentChargesSql = """
            SELECT TOP 3 ea.id, ea.date_created, ea.charge_amount, ea.charge_quantity, ea.payment_status
            FROM event_actions ea
            INNER JOIN route_events re ON re.id = ea.route_event_id
            WHERE re.account_number = @accountNumber AND re.district_id = @districtId
              AND ea.action_type = 'charge'
            ORDER BY ea.date_created DESC
            """;
        var recentCharges = (await db.QueryAsync<dynamic>(
            recentChargesSql, new { accountNumber, districtId })).ToList();

        const string eventDatesSql = """
            SELECT date_occurred FROM route_events
            WHERE account_number = @accountNumber AND district_id = @districtId AND date_occurred >= @cutoff90
            """;
        var eventDates = (await db.QueryAsync<DateTimeOffset>(
            eventDatesSql, new { accountNumber, districtId, cutoff90 })).ToList();

        var windows = new[] { 30, 60, 90 }.Select(days =>
        {
            var cutoff = now.AddDays(-days);
            var inWindow = accountCharges.Where(c => (DateTimeOffset)c.date_created >= cutoff).ToList();
            var paid = inWindow.Where(c => (string?)c.payment_status == "PAID").ToList();
            var refunded = inWindow.Where(c => (string?)c.payment_status == "REFUNDED").ToList();
            // Enumerable.Sum must not be used over dynamic rows: the lambda's
            // return type is dynamic, so the overload is picked at runtime and
            // binds to the int version, throwing on a decimal. Accumulate into
            // an explicitly typed local instead.
            static decimal Sum(IEnumerable<dynamic> rows)
            {
                decimal total = 0m;
                foreach (var c in rows)
                {
                    decimal amount = Convert.ToDecimal(c.charge_amount ?? 0m);
                    decimal quantity = Convert.ToDecimal(c.charge_quantity ?? 1m);
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

        DateTimeOffset? customerSince = row.customer_since is not null ? (DateTimeOffset?)row.customer_since : null;
        int? tenureMonths = customerSince.HasValue ? MonthsBetween(customerSince.Value, now) : null;
        string? lastChargeDate = recentCharges.Count > 0
            ? ((DateTimeOffset)recentCharges[0].date_created).ToString("O") : null;

        var statistics = new EventStatisticsDto(
            TenureMonths: tenureMonths,
            CustomerSince: customerSince?.ToString("O"),
            LastChargeDate: lastChargeDate,
            Windows: windows);

        var lastCharges = recentCharges.Select(c => new LastChargeDto(
            Id: (int)c.id,
            DateCreated: ((DateTimeOffset)c.date_created).ToString("O"),
            Amount: Convert.ToDecimal(c.charge_amount ?? 0m) * Convert.ToDecimal(c.charge_quantity ?? 1m),
            PaymentStatus: (string?)c.payment_status)).ToList();

        // Nearby events
        var anchorLat = (double)row.latitude;
        var anchorLon = (double)row.longitude;
        var anchorDate = (DateTimeOffset)row.date_occurred;
        var windowMs = TimeSpan.FromMinutes(_settings.NearbyWindowMinutes);
        var dateFrom = anchorDate - windowMs;
        var dateTo = anchorDate + windowMs;
        var distId = (int)row.district_id;
        var eId = (int)row.id;

        var nearbyRows = await QueryNearbyRowsAsync(eId, distId, anchorLat, anchorLon, dateFrom, dateTo);

        var nearbyIds = nearbyRows.Select(n => n.id).ToList();
        HashSet<int> chargedNearbyIds = [];
        if (nearbyIds.Count > 0)
        {
            var chargeActSql = $"""
                SELECT route_event_id FROM event_actions
                WHERE route_event_id IN ({string.Join(",", nearbyIds)}) AND action_type = 'charge'
                """;
            var chargeIds = await db.QueryAsync<int>(chargeActSql);
            chargedNearbyIds = [.. chargeIds];
        }

        var nearbyEvents = nearbyRows.Select(n =>
        {
            var offsetMs = (n.date_occurred - anchorDate).TotalSeconds;
            var isSuggestedDup = n.event_status == 0
                && n.distance_meters <= _settings.SuggestedDuplicateRadiusMeters
                && Math.Abs(offsetMs) <= _settings.SuggestedDuplicateWindowMinutes * 60;
            string status = n.event_status == 0 ? "Open"
                : chargedNearbyIds.Contains(n.id) ? "Charged" : "Dismissed";
            return new NearbyEventDto(
                Id: n.id, ImageUrl: n.image_url,
                DateOccurred: ((DateTimeOffset)n.date_occurred).ToString("O"),
                SecondsOffset: (int)offsetMs,
                EventStatus: n.event_status, Status: status,
                DistanceMeters: (int)Math.Round(n.distance_meters),
                IsSuggestedDuplicate: isSuggestedDup,
                EventSourceName: n.event_source_name ?? "",
                Address: n.address ?? "", CustomerName: n.customer_name ?? "",
                AccountNumber: n.account_number ?? "",
                BinSerialNumber: n.bin_serial_number,
                Vehicle: n.vehicle ?? "");
        }).ToList();

        var districtNumber = (string)row.district_number;
        var externalId = (string?)row.external_id;
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
            BillArea = (string?)row.bill_area,
            RmoStatus = (string?)row.rmo_status,
            Details = (string?)row.details,
            Latitude = (double)row.latitude,
            Longitude = (double)row.longitude,
            Routes = row.customer_routes is not null
                ? JsonSerializer.Deserialize<object>((string)row.customer_routes)
                : null,
            Actions = actions,
            Statistics = statistics,
            NearbyEvents = nearbyEvents,
            LastCharges = lastCharges,
            ShareLinks = new ShareLinksDto(
                Event: $"https://events.wcnx.org/{districtNumber}/events/{eId}",
                Photo: $"https://events.wcnx.org/{districtNumber}/imageproxy?url={Uri.EscapeDataString(row.image_url ?? "")}",
                Source: $"https://monitor.wastevision.ai/Media/Details?mediaId={externalId ?? eId.ToString()}")
        };
    }

    private async Task<List<dynamic>> QueryNearbyRowsAsync(
        int excludeId, int districtId, double anchorLat, double anchorLon,
        DateTimeOffset dateFrom, DateTimeOffset dateTo)
    {
        var sql = $"""
            SELECT TOP {_settings.NearbyMaxResults}
                re.id, re.image_url, re.date_occurred, re.event_status,
                re.address, re.customer_name, re.account_number, re.bin_serial_number, re.vehicle,
                es.name AS event_source_name,
                (2 * 6371000 * ATN2(
                    SQRT(
                        POWER(SIN(RADIANS(re.latitude - @anchorLat) / 2), 2)
                        + COS(RADIANS(@anchorLat)) * COS(RADIANS(re.latitude))
                        * POWER(SIN(RADIANS(re.longitude - @anchorLon) / 2), 2)
                    ),
                    SQRT(1 - (
                        POWER(SIN(RADIANS(re.latitude - @anchorLat) / 2), 2)
                        + COS(RADIANS(@anchorLat)) * COS(RADIANS(re.latitude))
                        * POWER(SIN(RADIANS(re.longitude - @anchorLon) / 2), 2)
                    ))
                )) AS distance_meters
            FROM route_events re
            INNER JOIN event_sources es ON es.id = re.event_source_id
            WHERE re.district_id = @districtId
              AND re.id <> @excludeId
              AND re.date_occurred >= @dateFrom
              AND re.date_occurred <= @dateTo
            HAVING (2 * 6371000 * ATN2(
                SQRT(
                    POWER(SIN(RADIANS(re.latitude - @anchorLat) / 2), 2)
                    + COS(RADIANS(@anchorLat)) * COS(RADIANS(re.latitude))
                    * POWER(SIN(RADIANS(re.longitude - @anchorLon) / 2), 2)
                ),
                SQRT(1 - (
                    POWER(SIN(RADIANS(re.latitude - @anchorLat) / 2), 2)
                    + COS(RADIANS(@anchorLat)) * COS(RADIANS(re.latitude))
                    * POWER(SIN(RADIANS(re.longitude - @anchorLon) / 2), 2)
                ))
            )) <= @radiusMeters
            ORDER BY distance_meters ASC, re.date_occurred ASC
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
            INSERT INTO event_actions (route_event_id, action_type, is_final, notes, created_by, date_created)
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
            var anchorLat = (double)evt.latitude;
            var anchorLon = (double)evt.longitude;
            var anchorDate = (DateTimeOffset)evt.date_occurred;
            var windowMs = TimeSpan.FromMinutes(_settings.NearbyWindowMinutes);
            var nearby = await QueryNearbyRowsAsync(
                eventId, (int)evt.district_id, anchorLat, anchorLon,
                anchorDate - windowMs, anchorDate + windowMs);
            var nearbySet = nearby.Select(n => (int)n.id).ToHashSet();
            if (!duplicateEventIds.All(id => nearbySet.Contains(id)))
                return (null, "duplicateEventIds must be nearby overages of this event");
        }

        if (db.State != ConnectionState.Open) db.Open();
        using var tx = db.BeginTransaction();
        try
        {
            // Check contract flag
            const string flagSql = """
                SELECT TOP 1 id FROM account_flags
                WHERE district_id = @districtId AND account_number = @accountNumber AND flag = 'contract_no_overages'
                """;
            var flag = await db.QueryFirstOrDefaultAsync<int?>(flagSql,
                new { districtId = (int)evt.district_id, accountNumber = (string)evt.account_number }, tx);
            if (flag.HasValue) return (null, "flagged");

            // Re-check open status with lock
            const string lockSql = "SELECT event_status FROM route_events WITH (UPDLOCK, HOLDLOCK) WHERE id = @id";
            var currentStatus = await db.QueryFirstOrDefaultAsync<int?>(lockSql, new { id = eventId }, tx);
            if (currentStatus is null || currentStatus != 0) return (null, "closed");

            const string insertSql = """
                INSERT INTO event_actions
                    (route_event_id, action_type, is_final, service_code_id, charge_amount, charge_quantity, created_by, date_created)
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
                    "UPDATE route_events SET event_status=1, date_closed=GETUTCDATE(), closed_by=@by WHERE id=@id",
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
            INSERT INTO event_actions (route_event_id, action_type, is_final, notes, created_by, date_created)
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
            var anchorLat = (double)evt.latitude;
            var anchorLon = (double)evt.longitude;
            var anchorDate = (DateTimeOffset)evt.date_occurred;
            var windowMs = TimeSpan.FromMinutes(_settings.NearbyWindowMinutes);
            var nearby = await QueryNearbyRowsAsync(
                eventId, (int)evt.district_id, anchorLat, anchorLon,
                anchorDate - windowMs, anchorDate + windowMs);
            var nearbySet = nearby.Select(n => (int)n.id).ToHashSet();
            if (!duplicateIds.All(id => nearbySet.Contains(id)))
                return (null, "duplicateEventIds must be nearby overages of this event");
        }

        if (db.State != ConnectionState.Open) db.Open();
        using var tx = db.BeginTransaction();
        try
        {
            const string closeSql = """
                UPDATE route_events SET event_status=1, date_closed=GETUTCDATE(), closed_by=@by
                OUTPUT INSERTED.id
                WHERE id=@id AND event_status=0
                """;
            var closedId = await db.QueryFirstOrDefaultAsync<int?>(closeSql,
                new { by = CurrentUser, id = eventId }, tx);
            if (!closedId.HasValue) { tx.Rollback(); return (null, "closed"); }

            const string actionSql = """
                INSERT INTO event_actions (route_event_id, action_type, is_final, close_reason, notes, created_by, date_created)
                OUTPUT INSERTED.*
                VALUES (@routeEventId, 'close', 1, @closeReason, @notes, @createdBy, GETUTCDATE())
                """;
            var action = await db.QueryFirstAsync<dynamic>(actionSql, new
            {
                routeEventId = eventId, closeReason, notes, createdBy = CurrentUser
            }, tx);

            if (closeReason == ContractCloseReason)
                await FlagAccountAsync((int)evt.district_id, (string)evt.account_number, tx);

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
        var targetsSql = $"SELECT id, district_id, account_number FROM route_events WHERE id IN ({inClause})";
        var targets = (await db.QueryAsync<dynamic>(targetsSql)).ToList();
        var districts = targets.Select(t => (int)t.district_id).Distinct().ToList();
        if (districts.Count > 1) throw new InvalidOperationException("All events must belong to the same district");

        if (db.State != ConnectionState.Open) db.Open();
        using var tx = db.BeginTransaction();
        try
        {
            var closeSql = $"""
                UPDATE route_events SET event_status=1, date_closed=GETUTCDATE(), closed_by=@by
                OUTPUT INSERTED.id
                WHERE id IN ({inClause}) AND event_status=0
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
                    $"INSERT INTO event_actions (route_event_id,action_type,is_final,close_reason,notes,created_by,date_created) VALUES {actionValues}", p, tx);

                if (closeReason == ContractCloseReason)
                {
                    var closedSet = closedIds.ToHashSet();
                    var toFlag = targets
                        .Where(t => closedSet.Contains((int)t.id))
                        .GroupBy(t => $"{t.district_id}:{t.account_number}")
                        .Select(g => g.First())
                        .ToList();
                    foreach (var t in toFlag)
                        await FlagAccountAsync((int)t.district_id, (string)t.account_number, tx);
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
        const string sql = "SELECT * FROM route_events WHERE id = @id";
        return await db.QueryFirstOrDefaultAsync<dynamic>(sql, new { id = eventId });
    }

    private async Task CloseDuplicatesAsync(List<int> ids, string reason, string notes, IDbTransaction tx)
    {
        var inClause = string.Join(",", ids);
        var closeSql = $"""
            UPDATE route_events SET event_status=1, date_closed=GETUTCDATE(), closed_by=@by
            OUTPUT INSERTED.id
            WHERE id IN ({inClause}) AND event_status=0
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
                $"INSERT INTO event_actions (route_event_id,action_type,is_final,close_reason,notes,created_by,date_created) VALUES {vals}", p, tx);
        }
    }

    private async Task FlagAccountAsync(int districtId, string accountNumber, IDbTransaction tx)
    {
        const string sql = """
            IF NOT EXISTS (
                SELECT 1 FROM account_flags WHERE district_id=@did AND account_number=@acct AND flag='contract_no_overages'
            )
            INSERT INTO account_flags (district_id, account_number, flag, created_by, date_created)
            VALUES (@did, @acct, 'contract_no_overages', @by, GETUTCDATE())
            """;
        await db.ExecuteAsync(sql, new { did = districtId, acct = accountNumber, by = CurrentUser }, tx);
    }

    private static EventActionDto SerializeAction(dynamic a) => new(
        Id: (int)a.id, RouteEventId: (int)a.route_event_id,
        ActionType: (string)a.action_type, IsFinal: (bool)a.is_final,
        Notes: (string?)a.notes, CloseReason: (string?)a.close_reason,
        ServiceCodeId: (int?)a.service_code_id,
        ChargeAmount: a.charge_amount is not null ? (decimal?)Convert.ToDecimal(a.charge_amount) : null,
        ChargeQuantity: a.charge_quantity is not null ? (decimal?)Convert.ToDecimal(a.charge_quantity) : null,
        PaymentStatus: (string?)a.payment_status,
        CreatedBy: (string)a.created_by,
        DateCreated: ((DateTimeOffset)a.date_created).ToString("O"));

    private static int MonthsBetween(DateTimeOffset from, DateTimeOffset to) =>
        Math.Max(0, (to.Year - from.Year) * 12 + (to.Month - from.Month));
}
