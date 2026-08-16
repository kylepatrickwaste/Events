using Dapper;
using Microsoft.Data.SqlClient;
using System.Text.RegularExpressions;

namespace Events.Api.Services;

/// <summary>
/// Creates all tables and seeds reference + mock data on first run.
/// Every operation is idempotent — safe to call on every startup.
/// </summary>
public static class DatabaseInitializer
{
    public static async Task InitializeAsync(string connectionString)
    {
        await using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        await MigrateLegacySnakeCaseSchemaAsync(conn);
        await CreateTablesAsync(conn);
        await AddMissingColumnsAsync(conn);
        await SeedLookupsAsync(conn);
        await SeedRouteEventsAsync(conn);
        await SeedEventActionsAsync(conn);
    }

    // ─── Legacy schema migration ──────────────────────────────────────────────

    /// <summary>
    /// The PascalCase schema, used both as the rename target for a legacy
    /// snake_case database and as the authoritative column list for it.
    /// </summary>
    private static readonly (string Table, string[] Columns)[] SchemaMap =
    {
        ("Districts",    new[] { "Id", "Number", "Name", "Region", "HaulingSystem", "Active" }),
        ("EventTypes",   new[] { "Id", "Name", "Active" }),
        ("EventSources", new[] { "Id", "Name", "Active" }),
        ("ServiceCodes", new[] { "Id", "DistrictId", "Code", "Description", "Amount", "Active" }),
        ("RouteEvents",  new[]
        {
            "Id", "DistrictId", "EventTypeId", "EventSourceId", "ExternalId", "DateOccurred",
            "Vehicle", "Route", "Latitude", "Longitude", "Address", "CustomerName",
            "AccountNumber", "BillArea", "BinSerialNumber", "Lob", "RmoStatus", "Details",
            "Stop", "WorkOrderNumber", "TabletNotes", "Quantity", "ImageUrl", "ImageUrls",
            "Severity", "CustomerSince", "EventStatus", "DateClosed", "ClosedBy", "CustomerRoutes",
            "FileImportId"
        }),
        ("EventActions", new[]
        {
            "Id", "RouteEventId", "ActionType", "IsFinal", "Notes", "CloseReason",
            "ServiceCodeId", "ChargeAmount", "ChargeQuantity", "BilledStatementNumber",
            "PaymentStatus", "BilledAmount", "CreatedBy", "DateCreated"
        }),
        ("AccountFlags", new[]
        {
            "Id", "DistrictId", "AccountNumber", "Flag", "CreatedBy", "DateCreated",
            "Name", "EventTypeId", "EventSourceId", "Notes", "Active"
        }),
        // Never existed in the snake_case era, so the rename pass below is a
        // guarded no-op for these. They are listed to keep this the single
        // authoritative column list.
        ("FileImports",      new[] { "Id", "FileName", "DateCreated" }),
        ("EventEditHistory", new[]
        {
            "Id", "RouteEventId", "Field", "OldValue", "NewValue", "CreatedBy", "DateCreated"
        }),
    };

    /// <summary>Indexes to rename, as (table, legacy name, new name).</summary>
    private static readonly (string Table, string Old, string New)[] LegacyIndexNames =
    {
        ("RouteEvents",  "route_events_account_date_idx",         "RouteEventsAccountDateIdx"),
        ("EventActions", "event_actions_route_event_idx",         "EventActionsRouteEventIdx"),
        ("AccountFlags", "account_flags_district_account_flag_idx", "AccountFlagsDistrictAccountFlagIdx"),
    };

    /// <summary>
    /// Constraints to rename. Only the explicitly named ones are listed —
    /// system-generated names (PK__districts__…) are left alone.
    /// </summary>
    private static readonly (string Old, string New)[] LegacyConstraintNames =
    {
        ("pk_districts", "PkDistricts"),
        ("df_districts_active", "DfDistrictsActive"),
        ("pk_event_types", "PkEventTypes"),
        ("df_event_types_active", "DfEventTypesActive"),
        ("pk_event_sources", "PkEventSources"),
        ("df_event_sources_active", "DfEventSourcesActive"),
        ("pk_service_codes", "PkServiceCodes"),
        ("df_service_codes_active", "DfServiceCodesActive"),
        ("fk_service_codes_district", "FkServiceCodesDistrict"),
        ("pk_route_events", "PkRouteEvents"),
        ("df_route_events_image_urls", "DfRouteEventsImageUrls"),
        ("df_route_events_event_status", "DfRouteEventsEventStatus"),
        ("df_route_events_customer_routes", "DfRouteEventsCustomerRoutes"),
        ("chk_route_events_image_urls", "ChkRouteEventsImageUrls"),
        ("chk_route_events_customer_routes", "ChkRouteEventsCustomerRoutes"),
        ("fk_route_events_district", "FkRouteEventsDistrict"),
        ("fk_route_events_event_type", "FkRouteEventsEventType"),
        ("fk_route_events_event_source", "FkRouteEventsEventSource"),
        ("pk_event_actions", "PkEventActions"),
        ("df_event_actions_is_final", "DfEventActionsIsFinal"),
        ("df_event_actions_date_created", "DfEventActionsDateCreated"),
        ("fk_event_actions_route_event", "FkEventActionsRouteEvent"),
        ("fk_event_actions_service_code", "FkEventActionsServiceCode"),
        ("pk_account_flags", "PkAccountFlags"),
        ("df_account_flags_flag", "DfAccountFlagsFlag"),
        ("df_account_flags_date_created", "DfAccountFlagsDateCreated"),
        ("fk_account_flags_district", "FkAccountFlagsDistrict"),
        ("UQ_account_flags_district_account_flag", "UqAccountFlagsDistrictAccountFlag"),
    };

    /// <summary>
    /// Renames a pre-PascalCase database in place with sp_rename: tables first,
    /// then columns, then indexes and named constraints. Rows are preserved —
    /// nothing is dropped and nothing is re-seeded over existing data.
    ///
    /// Every statement is guarded, so this is a no-op on a database that is
    /// already renamed and on an empty one. The guards compare names under a
    /// binary collation because SQL Server object names are case-insensitive:
    /// `districts` and `Districts` are the same object, so only a case-sensitive
    /// check can tell whether a rename is still outstanding.
    /// </summary>
    private static async Task MigrateLegacySnakeCaseSchemaAsync(SqlConnection conn)
    {
        const string renameTableSql = @"
IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = @legacy COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = @current COLLATE Latin1_General_BIN2)
    EXEC sp_rename @qualified, @current;";

        const string renameColumnSql = @"
IF OBJECT_ID(@table,'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(@table) AND name = @legacy COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(@table) AND name = @current COLLATE Latin1_General_BIN2)
    EXEC sp_rename @qualified, @current, 'COLUMN';";

        const string renameIndexSql = @"
IF OBJECT_ID(@table,'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(@table) AND name = @legacy)
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(@table) AND name = @current)
    EXEC sp_rename @qualified, @current, 'INDEX';";

        const string renameConstraintSql = @"
IF EXISTS (SELECT 1 FROM sys.objects WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = @legacy)
   AND NOT EXISTS (SELECT 1 FROM sys.objects WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = @current)
    EXEC sp_rename @qualified, @current;";

        foreach (var (table, _) in SchemaMap)
        {
            var legacy = ToSnakeCase(table);
            await conn.ExecuteAsync(renameTableSql,
                new { legacy, current = table, qualified = $"dbo.{legacy}" });
        }

        foreach (var (table, columns) in SchemaMap)
        {
            foreach (var column in columns)
            {
                var legacy = ToSnakeCase(column);
                await conn.ExecuteAsync(renameColumnSql, new
                {
                    table = $"dbo.{table}",
                    legacy,
                    current = column,
                    qualified = $"dbo.{table}.{legacy}"
                });
            }
        }

        foreach (var (table, oldName, newName) in LegacyIndexNames)
        {
            await conn.ExecuteAsync(renameIndexSql, new
            {
                table = $"dbo.{table}",
                legacy = oldName,
                current = newName,
                qualified = $"dbo.{table}.{oldName}"
            });
        }

        foreach (var (oldName, newName) in LegacyConstraintNames)
        {
            await conn.ExecuteAsync(renameConstraintSql,
                new { legacy = oldName, current = newName, qualified = $"dbo.{oldName}" });
        }
    }

    /// <summary>`RouteEvents` → `route_events`, `Id` → `id`.</summary>
    private static string ToSnakeCase(string pascal) =>
        Regex.Replace(pascal, "(?<!^)([A-Z])", "_$1").ToLowerInvariant();

    // ─── Schema ───────────────────────────────────────────────────────────────

    private static async Task CreateTablesAsync(SqlConnection conn)
    {
        // Tables must be created in FK-dependency order.
        await conn.ExecuteAsync(@"
IF OBJECT_ID('Districts','U') IS NULL
CREATE TABLE Districts (
    Id            INT            IDENTITY(1,1) PRIMARY KEY,
    Number        NVARCHAR(50)   NOT NULL,
    Name          NVARCHAR(255)  NOT NULL,
    Region        NVARCHAR(100)  NOT NULL,
    HaulingSystem INT            NULL,
    Active        BIT            NOT NULL DEFAULT 1
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('EventTypes','U') IS NULL
CREATE TABLE EventTypes (
    Id     INT           IDENTITY(1,1) PRIMARY KEY,
    Name   NVARCHAR(255) NOT NULL,
    Active BIT           NOT NULL DEFAULT 1
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('EventSources','U') IS NULL
CREATE TABLE EventSources (
    Id     INT           IDENTITY(1,1) PRIMARY KEY,
    Name   NVARCHAR(255) NOT NULL,
    Active BIT           NOT NULL DEFAULT 1
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('ServiceCodes','U') IS NULL
CREATE TABLE ServiceCodes (
    Id          INT            IDENTITY(1,1) PRIMARY KEY,
    DistrictId  INT            NOT NULL REFERENCES Districts(Id),
    Code        NVARCHAR(50)   NOT NULL,
    Description NVARCHAR(500)  NOT NULL,
    Amount      DECIMAL(12,4)  NOT NULL,
    Active      BIT            NOT NULL DEFAULT 1
);");

        // `Flag` is this schema's name for what the target schema calls
        // `Reason`; the other exclusion columns below match it one for one.
        // A NULL EventTypeId/EventSourceId means the exclusion applies to
        // every type/source rather than being scoped to one.
        await conn.ExecuteAsync(@"
IF OBJECT_ID('AccountFlags','U') IS NULL
CREATE TABLE AccountFlags (
    Id            INT              IDENTITY(1,1) PRIMARY KEY,
    DistrictId    INT              NOT NULL REFERENCES Districts(Id),
    AccountNumber NVARCHAR(50)     NOT NULL,
    Name          NVARCHAR(250)    NULL,
    EventTypeId   INT              NULL REFERENCES EventTypes(Id),
    EventSourceId INT              NULL REFERENCES EventSources(Id),
    Flag          NVARCHAR(100)    NOT NULL DEFAULT 'contract_no_overages',
    Notes         NVARCHAR(500)    NULL,
    Active        BIT              NOT NULL DEFAULT 1,
    CreatedBy     NVARCHAR(100)    NOT NULL,
    DateCreated   DATETIMEOFFSET   NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UqAccountFlagsDistrictAccountFlag
        UNIQUE (DistrictId, AccountNumber, Flag)
);");

        // Import provenance for RouteEvents. Created before RouteEvents so the
        // FileImportId foreign key below has something to point at.
        await conn.ExecuteAsync(@"
IF OBJECT_ID('FileImports','U') IS NULL
CREATE TABLE FileImports (
    Id          INT              IDENTITY(1,1) PRIMARY KEY,
    FileName    NVARCHAR(255)    NOT NULL,
    DateCreated DATETIMEOFFSET   NOT NULL DEFAULT SYSDATETIMEOFFSET()
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('RouteEvents','U') IS NULL
CREATE TABLE RouteEvents (
    Id              INT              IDENTITY(1,1) PRIMARY KEY,
    DistrictId      INT              NOT NULL REFERENCES Districts(Id),
    EventTypeId     INT              NOT NULL REFERENCES EventTypes(Id),
    EventSourceId   INT              NOT NULL REFERENCES EventSources(Id),
    ExternalId      NVARCHAR(100)    NULL,
    DateOccurred    DATETIMEOFFSET   NOT NULL,
    Vehicle         NVARCHAR(100)    NOT NULL,
    Route           NVARCHAR(50)     NOT NULL,
    Latitude        FLOAT            NOT NULL,
    Longitude       FLOAT            NOT NULL,
    Address         NVARCHAR(500)    NOT NULL,
    CustomerName    NVARCHAR(255)    NOT NULL,
    AccountNumber   NVARCHAR(50)     NOT NULL,
    BillArea        NVARCHAR(100)    NULL,
    BinSerialNumber NVARCHAR(100)    NULL,
    Lob             NVARCHAR(100)    NULL,
    RmoStatus       NVARCHAR(100)    NULL,
    Details         NVARCHAR(MAX)    NULL,
    Stop            NVARCHAR(50)     NULL,
    WorkOrderNumber NVARCHAR(100)    NULL,
    TabletNotes     NVARCHAR(MAX)    NULL,
    Quantity        DECIMAL(9,2)     NULL,
    ImageUrl        NVARCHAR(500)    NULL,
    ImageUrls       NVARCHAR(MAX)    NOT NULL DEFAULT '[]',
    Severity        NVARCHAR(50)     NULL,
    CustomerSince   DATETIMEOFFSET   NULL,
    EventStatus     INT              NOT NULL DEFAULT 0,
    DateClosed      DATETIMEOFFSET   NULL,
    ClosedBy        NVARCHAR(100)    NULL,
    CustomerRoutes  NVARCHAR(MAX)    NOT NULL DEFAULT '[]',
    FileImportId    INT              NULL REFERENCES FileImports(Id)
);");

        await conn.ExecuteAsync(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='RouteEventsAccountDateIdx')
    CREATE INDEX RouteEventsAccountDateIdx ON RouteEvents(AccountNumber, DateOccurred);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('EventActions','U') IS NULL
CREATE TABLE EventActions (
    Id                    INT              IDENTITY(1,1) PRIMARY KEY,
    RouteEventId          INT              NOT NULL REFERENCES RouteEvents(Id),
    ActionType            NVARCHAR(50)     NOT NULL,
    IsFinal               BIT              NOT NULL DEFAULT 0,
    Notes                 NVARCHAR(MAX)    NULL,
    CloseReason           NVARCHAR(255)    NULL,
    ServiceCodeId         INT              NULL REFERENCES ServiceCodes(Id),
    ChargeAmount          DECIMAL(12,4)    NULL,
    ChargeQuantity        DECIMAL(9,2)     NULL,
    BilledStatementNumber NVARCHAR(100)    NULL,
    PaymentStatus         NVARCHAR(50)     NULL,
    BilledAmount          DECIMAL(12,4)    NULL,
    CreatedBy             NVARCHAR(100)    NOT NULL,
    DateCreated           DATETIMEOFFSET   NOT NULL DEFAULT SYSDATETIMEOFFSET()
);");

        await conn.ExecuteAsync(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='EventActionsRouteEventIdx')
    CREATE INDEX EventActionsRouteEventIdx ON EventActions(RouteEventId);");

        // Per-field audit trail: one row per changed value, so a single edit
        // that touches three fields writes three rows.
        await conn.ExecuteAsync(@"
IF OBJECT_ID('EventEditHistory','U') IS NULL
CREATE TABLE EventEditHistory (
    Id           INT              IDENTITY(1,1) PRIMARY KEY,
    RouteEventId INT              NOT NULL REFERENCES RouteEvents(Id),
    Field        NVARCHAR(50)     NOT NULL,
    OldValue     NVARCHAR(500)    NULL,
    NewValue     NVARCHAR(500)    NULL,
    CreatedBy    NVARCHAR(100)    NOT NULL,
    DateCreated  DATETIMEOFFSET   NOT NULL DEFAULT SYSDATETIMEOFFSET()
);");

        await conn.ExecuteAsync(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='EventEditHistoryRouteEventIdx')
    CREATE INDEX EventEditHistoryRouteEventIdx ON EventEditHistory(RouteEventId);");

        // Users are created on first contact by AppUsersRepository, not seeded.
        // HomeDistrictNumber stores the district Number rather than a FK to
        // Districts(Id) on purpose: the seed routines below reassign identity
        // values on every start, so an Id would silently point at a different
        // district after a re-seed.
        await conn.ExecuteAsync(@"
IF OBJECT_ID('AppUsers','U') IS NULL
CREATE TABLE AppUsers (
    Id                  INT              IDENTITY(1,1) PRIMARY KEY,
    ActiveDirectoryName NVARCHAR(256)    NOT NULL,
    FriendlyName        NVARCHAR(256)    NULL,
    HomeDistrictNumber  NVARCHAR(50)     NULL,
    Role                NVARCHAR(50)     NULL DEFAULT 'Agent',
    DateLastSeen        DATETIMEOFFSET   NULL,
    Active              BIT              NOT NULL DEFAULT 1,
    DateCreated         DATETIMEOFFSET   NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UqAppUsersActiveDirectoryName UNIQUE (ActiveDirectoryName)
);");
    }

    // ─── Column back-fill ─────────────────────────────────────────────────────

    /// <summary>
    /// Columns added to tables that already exist in a deployed database.
    /// <see cref="CreateTablesAsync"/> only runs its CREATE when the table is
    /// absent, so a database created before these columns existed would never
    /// pick them up without this pass. Each entry is the exact text that
    /// follows <c>ALTER TABLE &lt;table&gt; ADD</c>.
    /// </summary>
    private static readonly (string Table, string Column, string Definition)[] AddedColumns =
    {
        ("AccountFlags", "Name",          "Name NVARCHAR(250) NULL"),
        ("AccountFlags", "EventTypeId",   "EventTypeId INT NULL CONSTRAINT FkAccountFlagsEventType REFERENCES EventTypes(Id)"),
        ("AccountFlags", "EventSourceId", "EventSourceId INT NULL CONSTRAINT FkAccountFlagsEventSource REFERENCES EventSources(Id)"),
        ("AccountFlags", "Notes",         "Notes NVARCHAR(500) NULL"),
        ("AccountFlags", "Active",        "Active BIT NOT NULL CONSTRAINT DfAccountFlagsActive DEFAULT 1"),
        ("RouteEvents",  "FileImportId",  "FileImportId INT NULL CONSTRAINT FkRouteEventsFileImport REFERENCES FileImports(Id)"),
    };

    /// <summary>
    /// Adds any column in <see cref="AddedColumns"/> that the live database is
    /// missing. Idempotent: a column that is already present is skipped, so
    /// this is a no-op on a freshly created database.
    ///
    /// The NOT NULL entries carry a named DEFAULT because SQL Server needs one
    /// to back-fill existing rows; without it the ALTER fails on any table that
    /// already holds data.
    /// </summary>
    private static async Task AddMissingColumnsAsync(SqlConnection conn)
    {
        foreach (var (table, column, definition) in AddedColumns)
        {
            // Identifiers cannot be parameterised, but none of these values are
            // user input — they are the compile-time constants above.
            await conn.ExecuteAsync($@"
IF OBJECT_ID('dbo.{table}','U') IS NOT NULL AND COL_LENGTH('dbo.{table}','{column}') IS NULL
    ALTER TABLE {table} ADD {definition};");
        }
    }

    // ─── Lookup seed data ─────────────────────────────────────────────────────

    private static async Task SeedLookupsAsync(SqlConnection conn)
    {
        // EventTypes
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM EventTypes") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT EventTypes ON;
INSERT INTO EventTypes (Id, Name, Active) VALUES
  (1, 'Extra', 1),
  (2, 'Contamination', 1),
  (3, 'Overloaded', 1),
  (4, 'Blocked Container', 1),
  (5, 'Not Out', 1);
SET IDENTITY_INSERT EventTypes OFF;");
        }

        // EventSources
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM EventSources") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT EventSources ON;
INSERT INTO EventSources (Id, Name, Active) VALUES
  (1, 'WasteVision', 1),
  (2, '3rd Eye', 1),
  (3, 'Manual', 1);
SET IDENTITY_INSERT EventSources OFF;");
        }

        // Districts
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM Districts") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT Districts ON;
INSERT INTO Districts (Id, Number, Name, Region, HaulingSystem, Active) VALUES
  (1,  '2010', 'VANCOUVER',                       'Western',  1, 1),
  (2,  '2011', 'OREGON PAPER FIBER',               'Western',  1, 1),
  (3,  '2012', 'CASCADE DISPOSAL',                 'Western',  1, 1),
  (4,  '2013', 'SANIPAC',                           'Western',  1, 1),
  (5,  '2021', 'KAHUT WASTE SERVICES',              'Western',  1, 1),
  (6,  '2025', 'COLUMBIA RIVER DISPOSAL',           'Western',  1, 1),
  (7,  '2032', 'WASTE CONTROL, INC',                'Western',  1, 1),
  (8,  '2040', 'CTR',                               'Western',  1, 1),
  (9,  '2043', 'SWEET HOME SANITATION',             'Western',  1, 1),
  (10, '2044', 'THE DALLES DISPOSAL',               'Western',  1, 1),
  (11, '2045', 'HOOD RIVER GARBAGE',                'Western',  1, 1),
  (12, '2046', 'ENVIRONMENTAL WASTE SYS',           'Western',  1, 1),
  (13, '2047', 'COOS COUNTY',                       'Western',  1, 1),
  (14, '2054', 'SANITARY DISPOSAL',                 'Western',  1, 1),
  (15, '2061', 'ROGUE DISPOSAL & RECYCLING, INC',  'Western',  1, 1),
  (16, '2064', 'ROGUE SHRED, LLC',                  'Western',  1, 1),
  (17, '2111', 'TACOMA HAULING',                    'Western',  1, 1),
  (18, '2112', 'PENINSULA HAULING',                 'Western',  1, 1),
  (19, '2120', 'EMPIRE DISPOSAL, INC.',             'Western',  1, 1),
  (20, '5120', 'WASTE CONNECTIONS OF TEXAS',        'Southern', 2, 1);
SET IDENTITY_INSERT Districts OFF;");
        }

        // ServiceCodes
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM ServiceCodes") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT ServiceCodes ON;
INSERT INTO ServiceCodes (Id, DistrictId, Code, Description, Amount, Active) VALUES
  (1, 20, 'EXTRA-COM', 'Extra pickup - Commercial ** Prefer RMO **', 75.0000, 1),
  (2, 20, 'EXTRA-RES', 'Extra pickup - Residential',                 35.0000, 1),
  (3, 20, 'CONTAM',    'Contamination charge',                       95.0000, 1),
  (4, 20, 'OVERLOAD',  'Overloaded container charge',                65.0000, 1),
  (5, 20, 'GATE',      'Gate / access fee',                          15.0000, 1),
  (6,  1, 'EXTRA-COM', 'Extra pickup - Commercial',                  70.0000, 1),
  (7,  1, 'CONTAM',    'Contamination charge',                       90.0000, 1),
  (8,  1, 'OVERLOAD',  'Overloaded container charge',                60.0000, 1);
SET IDENTITY_INSERT ServiceCodes OFF;");
        }
    }

    // ─── Route events seed ────────────────────────────────────────────────────

    private static async Task SeedRouteEventsAsync(SqlConnection conn)
    {
        // Skip entirely if events already exist
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM RouteEvents") > 0) return;

        const string sql = @"
INSERT INTO RouteEvents
    (DistrictId, EventTypeId, EventSourceId, ExternalId,
     DateOccurred, Vehicle, Route, Latitude, Longitude,
     Address, CustomerName, AccountNumber,
     BillArea, BinSerialNumber, Lob, Severity, Quantity,
     ImageUrl, ImageUrls,
     EventStatus, DateClosed, ClosedBy)
VALUES
    (@DistrictId, @EventTypeId, @EventSourceId, @ExternalId,
     @DateOccurred, @Vehicle, @Route, @Latitude, @Longitude,
     @Address, @CustomerName, @AccountNumber,
     @BillArea, @BinSerialNumber, @Lob, @Severity, @Quantity,
     @ImageUrl, @ImageUrls,
     @EventStatus, @DateClosed, @ClosedBy)";

        var imgs = new Func<int[], string>(ids =>
            ids.Length == 0 ? "[]"
            : "[" + string.Join(",", ids.Select(n => $"\"/event-photos/truck-cam-{n}.jpg\"")) + "]");
        var photo = new Func<int, string?>(n => n == 0 ? null : $"/event-photos/truck-cam-{n}.jpg");

        var rows = new[]
        {
            // ── District 20 (Texas) ──────────────────────────────────────────
            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"12225447",
                  DateOccurred="2026-08-04T19:51:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.991, Longitude=-95.4227, Address="15155 NORTH FREEWAY, HOUSTON, TX",
                  CustomerName="OJOS LOCOS NORTH FWY", AccountNumber="5120-7786202",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"BIN-88231", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([2,3,1,4,5]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"12225512",
                  DateOccurred="2026-08-05T13:51:00+00:00", Vehicle="5120-2311 FEL", Route="NY305",
                  Latitude=29.7604, Longitude=-95.3698, Address="2401 MAIN ST, HOUSTON, TX",
                  CustomerName="LONE STAR CANTINA", AccountNumber="5120-7712045",
                  BillArea=(string?)"HARRIS/MTA Z2", BinSerialNumber=(string?)"BIN-77120", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)2m,
                  ImageUrl=photo(4), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=2, EventSourceId=1, ExternalId=(string?)"12225533",
                  DateOccurred="2026-08-05T23:51:00+00:00", Vehicle="5120-2315 REL", Route="RC201",
                  Latitude=29.8168, Longitude=-95.4012, Address="8800 AIRLINE DR, HOUSTON, TX",
                  CustomerName="PARK TRAILS APARTMENTS", AccountNumber="5120-7734411",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"BIN-90112", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(5), ImageUrls=imgs([6,7,1,2,3]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=3, EventSourceId=2, ExternalId=(string?)"12225390",
                  DateOccurred="2026-08-03T19:51:00+00:00", Vehicle="5120-2302 FEL", Route="NY605",
                  Latitude=29.737, Longitude=-95.4613, Address="5900 WESTHEIMER RD, HOUSTON, TX",
                  CustomerName="GALLERIA FOOD COURT", AccountNumber="5120-7701993",
                  BillArea=(string?)"HARRIS/MTA Z1", BinSerialNumber=(string?)"BIN-66102", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(2), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=5, EventSourceId=3, ExternalId=(string?)"12225281",
                  DateOccurred="2026-08-02T19:51:00+00:00", Vehicle="5120-2408 RSL", Route="RS114",
                  Latitude=29.92, Longitude=-95.21, Address="12207 EAST LAKE DR, HUMBLE, TX",
                  CustomerName="THOMPSON, MARGARET", AccountNumber="5120-7642210",
                  BillArea=(string?)"HARRIS/RES Z6", BinSerialNumber=(string?)null, Lob=(string?)"Residential",
                  Severity=(string?)"Minimal", Quantity=(decimal?)3m,
                  ImageUrl=photo(0), ImageUrls=imgs([]),
                  EventStatus=1, DateClosed=(string?)"2026-08-03T19:51:00+00:00", ClosedBy=(string?)"Maria.Gonzalez" },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"12225301",
                  DateOccurred="2026-08-01T19:51:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.9955, Longitude=-95.415, Address="202 RICHEY RD, HOUSTON, TX",
                  CustomerName="NORTH FWY TRUCK STOP", AccountNumber="5120-7688109",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"BIN-55020", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(3), ImageUrls=imgs([]),
                  EventStatus=1, DateClosed=(string?)"2026-08-02T19:51:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            // ── District 1 (Vancouver) ───────────────────────────────────────
            new { DistrictId=1, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"88110234",
                  DateOccurred="2026-08-05T19:51:00+00:00", Vehicle="2010-118 FEL", Route="VA204",
                  Latitude=45.6387, Longitude=-122.6615, Address="7720 NE VANCOUVER MALL DR, VANCOUVER, WA",
                  CustomerName="CASCADE STATION RETAIL", AccountNumber="2010-4410092",
                  BillArea=(string?)"CLARK Z2", BinSerialNumber=(string?)"BIN-20115", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(6), ImageUrls=imgs([1,2,3,4]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=1, EventTypeId=2, EventSourceId=2, ExternalId=(string?)"88110301",
                  DateOccurred="2026-08-04T19:51:00+00:00", Vehicle="2010-121 REL", Route="VR310",
                  Latitude=45.628, Longitude=-122.674, Address="3311 MAIN ST, VANCOUVER, WA",
                  CustomerName="UPTOWN LOFTS", AccountNumber="2010-4433001",
                  BillArea=(string?)"CLARK Z1", BinSerialNumber=(string?)"BIN-31200", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(0), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── District 20 (WV/nearby cluster area) ────────────────────────
            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-90311",
                  DateOccurred="2026-08-04T19:55:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.9922, Longitude=-95.4219, Address="4415 NORTH FWY",
                  CustomerName="NORTH FWY PLAZA", AccountNumber="5120-7786455",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-217", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(7), ImageUrls=imgs([4,1,2,3]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-90312",
                  DateOccurred="2026-08-04T19:44:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.9901, Longitude=-95.4212, Address="4380 NORTH FWY",
                  CustomerName="FWY SELF STORAGE", AccountNumber="5120-7786990",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-230", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(5), ImageUrls=imgs([]),
                  EventStatus=1, DateClosed=(string?)"2026-08-12T16:14:39+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            // ── District 20 — closed historical events ───────────────────────
            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-8701",
                  DateOccurred="2026-07-20T19:51:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.991, Longitude=-95.4227, Address="15155 NORTH FREEWAY, HOUSTON, TX",
                  CustomerName="OJOS LOCOS NORTH FWY", AccountNumber="5120-7786202",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-243", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(0), ImageUrls=imgs([]),
                  EventStatus=1, DateClosed=(string?)"2026-07-21T19:51:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-8702",
                  DateOccurred="2026-07-08T19:51:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.991, Longitude=-95.4227, Address="15155 NORTH FREEWAY, HOUSTON, TX",
                  CustomerName="OJOS LOCOS NORTH FWY", AccountNumber="5120-7786202",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-256", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([]),
                  EventStatus=1, DateClosed=(string?)"2026-07-09T19:51:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-8703",
                  DateOccurred="2026-06-26T19:51:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.991, Longitude=-95.4227, Address="15155 NORTH FREEWAY, HOUSTON, TX",
                  CustomerName="OJOS LOCOS NORTH FWY", AccountNumber="5120-7786202",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-269", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(7), ImageUrls=imgs([2,5,1,3,4]),
                  EventStatus=1, DateClosed=(string?)"2026-06-27T19:51:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-90312-B",
                  DateOccurred="2026-08-04T19:38:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.993, Longitude=-95.4215, Address="4419 NORTH FWY",
                  CustomerName="FWY PLAZA SUITE B", AccountNumber="5120-7786460",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-282", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(2), ImageUrls=imgs([2,1,3,4]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=2, EventSourceId=1, ExternalId=(string?)"WV-90313",
                  DateOccurred="2026-08-04T20:12:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.9916, Longitude=-95.4226, Address="4403 NORTH FWY",
                  CustomerName="NORTH FWY STORAGE", AccountNumber="5120-7786472",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-295", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(3), ImageUrls=imgs([3,1,2,4]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-90314",
                  DateOccurred="2026-08-04T19:47:00+00:00", Vehicle="5120-2309 FEL", Route="NY109",
                  Latitude=29.9925, Longitude=-95.421, Address="4421 NORTH FWY",
                  CustomerName="PLAZA DELI & MARKET", AccountNumber="5120-7786481",
                  BillArea=(string?)"HARRIS/MTA Z4", BinSerialNumber=(string?)"R6-308", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(5), ImageUrls=imgs([5,1,2,3]),
                  EventStatus=1, DateClosed=(string?)"2026-08-04T21:30:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            // ── District 15 (Rogue Disposal) ─────────────────────────────────
            new { DistrictId=15, EventTypeId=3, EventSourceId=3, ExternalId=(string?)"WV-88200000",
                  DateOccurred="2026-08-09T12:09:00+00:00", Vehicle="2010-2134 REL", Route="SW502",
                  Latitude=44.1472, Longitude=-122.5474, Address="5039 OAK ST",
                  CustomerName="RIVERSIDE APARTMENTS", AccountNumber="2010-7689491",
                  BillArea=(string?)"ZONE 2", BinSerialNumber=(string?)"R6-321", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(2), ImageUrls=imgs([2,4,5]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=15, EventTypeId=1, EventSourceId=2, ExternalId=(string?)"WV-88200001",
                  DateOccurred="2026-08-10T16:48:00+00:00", Vehicle="2010-2392 FEL", Route="VA550",
                  Latitude=44.69, Longitude=-121.3281, Address="1574 MAIN ST",
                  CustomerName="MAPLE ST DINER", AccountNumber="2010-7242480",
                  BillArea=(string?)"ZONE 1", BinSerialNumber=(string?)"R6-334", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(3), ImageUrls=imgs([3,4,6]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── District 3 (Cascade Disposal) ────────────────────────────────
            new { DistrictId=3, EventTypeId=3, EventSourceId=3, ExternalId=(string?)"WV-88200002",
                  DateOccurred="2026-08-05T13:24:00+00:00", Vehicle="2010-2129 ASL", Route="SW397",
                  Latitude=44.0677, Longitude=-121.4858, Address="1767 OAK ST",
                  CustomerName="GRANDVIEW MEDICAL", AccountNumber="2010-7889166",
                  BillArea=(string?)"ZONE 4", BinSerialNumber=(string?)"R6-347", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([1,2,3]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=15, EventTypeId=4, EventSourceId=2, ExternalId=(string?)"WV-88200003",
                  DateOccurred="2026-08-02T11:04:00+00:00", Vehicle="2010-2397 REL", Route="VA265",
                  Latitude=46.7133, Longitude=-122.3148, Address="6658 HARBOR DR",
                  CustomerName="CEDAR MILL LOFTS", AccountNumber="2010-7197496",
                  BillArea=(string?)"ZONE 2", BinSerialNumber=(string?)"R6-360", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([1,7,6,5]),
                  EventStatus=1, DateClosed=(string?)"2026-08-02T22:00:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            new { DistrictId=1, EventTypeId=3, EventSourceId=3, ExternalId=(string?)"WV-88200004",
                  DateOccurred="2026-08-10T17:10:00+00:00", Vehicle="2010-2264 REL", Route="NY289",
                  Latitude=44.0955, Longitude=-122.5136, Address="4283 SE FOSTER RD",
                  CustomerName="SUNSET STRIP MALL", AccountNumber="2010-7700892",
                  BillArea=(string?)"ZONE 4", BinSerialNumber=(string?)"R6-373", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(2), ImageUrls=imgs([2,3]),
                  EventStatus=1, DateClosed=(string?)"2026-08-10T22:00:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            // ── District 17 (Tacoma Hauling) ─────────────────────────────────
            new { DistrictId=17, EventTypeId=5, EventSourceId=2, ExternalId=(string?)"WV-88200005",
                  DateOccurred="2026-08-12T12:34:00+00:00", Vehicle="2010-2155 ASL", Route="VA109",
                  Latitude=46.6916, Longitude=-121.3529, Address="2041 NE BROADWAY",
                  CustomerName="HARBOR SEAFOOD CO", AccountNumber="2010-7146485",
                  BillArea=(string?)"ZONE 1", BinSerialNumber=(string?)"R6-386", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(5), ImageUrls=imgs([5,3,4,2,6]),
                  EventStatus=1, DateClosed=(string?)"2026-08-12T22:00:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            // ── District 1 — open events ─────────────────────────────────────
            new { DistrictId=1, EventTypeId=5, EventSourceId=3, ExternalId=(string?)"WV-88200006",
                  DateOccurred="2026-08-09T10:37:00+00:00", Vehicle="2010-2355 REL", Route="VA420",
                  Latitude=46.4755, Longitude=-121.6684, Address="1824 HARBOR DR",
                  CustomerName="PIONEER SQUARE OFFICES", AccountNumber="2010-7649511",
                  BillArea=(string?)"ZONE 3", BinSerialNumber=(string?)"R6-399", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(4), ImageUrls=imgs([4,6,5]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── District 17 — open ───────────────────────────────────────────
            new { DistrictId=17, EventTypeId=2, EventSourceId=2, ExternalId=(string?)"WV-88200007",
                  DateOccurred="2026-08-01T06:31:00+00:00", Vehicle="2010-2287 ASL", Route="VA552",
                  Latitude=44.9031, Longitude=-122.3055, Address="8556 OAK ST",
                  CustomerName="EASTSIDE AUTO PARTS", AccountNumber="2010-7354264",
                  BillArea=(string?)"ZONE 4", BinSerialNumber=(string?)"R6-412", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([1,2]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── District 1 — closed ──────────────────────────────────────────
            new { DistrictId=1, EventTypeId=4, EventSourceId=3, ExternalId=(string?)"WV-88200008",
                  DateOccurred="2026-08-09T07:55:00+00:00", Vehicle="2010-2218 FEL", Route="VA527",
                  Latitude=44.7979, Longitude=-121.6767, Address="8460 SE FOSTER RD",
                  CustomerName="BLUE HERON BREWERY", AccountNumber="2010-7884808",
                  BillArea=(string?)"ZONE 2", BinSerialNumber=(string?)"R6-425", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(6), ImageUrls=imgs([6,1,4,5]),
                  EventStatus=1, DateClosed=(string?)"2026-08-09T22:00:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            // ── District 3 — open ────────────────────────────────────────────
            new { DistrictId=3, EventTypeId=3, EventSourceId=1, ExternalId=(string?)"WV-88200009",
                  DateOccurred="2026-08-04T14:45:00+00:00", Vehicle="2010-2272 FEL", Route="VA483",
                  Latitude=46.7109, Longitude=-122.6036, Address="7561 HARBOR DR",
                  CustomerName="WILLAMETTE STORAGE", AccountNumber="2010-7605538",
                  BillArea=(string?)"ZONE 1", BinSerialNumber=(string?)"R6-438", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(2), ImageUrls=imgs([2,6,3]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── District 20 — closed ─────────────────────────────────────────
            new { DistrictId=20, EventTypeId=2, EventSourceId=2, ExternalId=(string?)"WV-88200010",
                  DateOccurred="2026-08-05T11:07:00+00:00", Vehicle="5120-2122 ASL", Route="NY293",
                  Latitude=46.7849, Longitude=-121.3825, Address="7318 HARBOR DR",
                  CustomerName="OAKRIDGE ELEMENTARY", AccountNumber="5120-7281391",
                  BillArea=(string?)"ZONE 1", BinSerialNumber=(string?)"R6-451", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([1,7]),
                  EventStatus=1, DateClosed=(string?)"2026-08-05T22:00:00+00:00", ClosedBy=(string?)"Kyle.Patrick" },

            // ── District 3 — open ────────────────────────────────────────────
            new { DistrictId=3, EventTypeId=5, EventSourceId=3, ExternalId=(string?)"WV-88200011",
                  DateOccurred="2026-08-07T11:25:00+00:00", Vehicle="2010-2378 ASL", Route="NY557",
                  Latitude=44.0304, Longitude=-121.7097, Address="3716 MAIN ST",
                  CustomerName="PACIFIC CREST GYM", AccountNumber="2010-7328774",
                  BillArea=(string?)"ZONE 3", BinSerialNumber=(string?)"R6-464", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(6), ImageUrls=imgs([6,4,1,2]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── District 17 — open ───────────────────────────────────────────
            new { DistrictId=17, EventTypeId=5, EventSourceId=2, ExternalId=(string?)"WV-88200012",
                  DateOccurred="2026-08-11T09:59:00+00:00", Vehicle="2010-2239 REL", Route="NY137",
                  Latitude=46.5642, Longitude=-121.8589, Address="3392 NE BROADWAY",
                  CustomerName="TIMBERLINE HARDWARE", AccountNumber="2010-7183777",
                  BillArea=(string?)"ZONE 1", BinSerialNumber=(string?)"R6-477", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([1,5,4]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── District 1 — open ────────────────────────────────────────────
            new { DistrictId=1, EventTypeId=5, EventSourceId=1, ExternalId=(string?)"WV-88200013",
                  DateOccurred="2026-08-06T16:26:00+00:00", Vehicle="2010-2262 FEL", Route="SW186",
                  Latitude=46.26, Longitude=-121.4862, Address="7774 OAK ST",
                  CustomerName="FOSTER RD LAUNDRY", AccountNumber="2010-7827457",
                  BillArea=(string?)"ZONE 4", BinSerialNumber=(string?)"R6-490", Lob=(string?)"Commercial",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(2), ImageUrls=imgs([2,1,7]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=1, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"WV-88200014",
                  DateOccurred="2026-08-05T17:52:00+00:00", Vehicle="2010-2265 ASL", Route="NY581",
                  Latitude=45.6984, Longitude=-122.3003, Address="3610 CEDAR BLVD",
                  CustomerName="KLICKITAT MARKET", AccountNumber="2010-7573938",
                  BillArea=(string?)"ZONE 1", BinSerialNumber=(string?)"R6-503", Lob=(string?)"Commercial",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(4), ImageUrls=imgs([4,3,1,7,6]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── Duplicate clusters — District 1 ──────────────────────────────
            new { DistrictId=1, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"DUPSEED-2010-A1",
                  DateOccurred="2026-08-14T08:12:00+00:00", Vehicle="2010-118 FEL", Route="VA204",
                  Latitude=45.6339, Longitude=-122.6031, Address="11505 NE FOURTH PLAIN BLVD, VANCOUVER, WA",
                  CustomerName="ORCHARDS MARKET CENTER", AccountNumber="2010-4451220",
                  BillArea=(string?)"054", BinSerialNumber=(string?)"R6-516", Lob=(string?)"RESIDENTIAL",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=1, EventTypeId=1, EventSourceId=2, ExternalId=(string?)"DUPSEED-2010-A2",
                  DateOccurred="2026-08-14T08:14:00+00:00", Vehicle="2010-121 REL", Route="VA204",
                  Latitude=45.6341, Longitude=-122.6032, Address="11505 NE FOURTH PLAIN BLVD, VANCOUVER, WA",
                  CustomerName="ORCHARDS MARKET CENTER", AccountNumber="2010-4451220",
                  BillArea=(string?)"061", BinSerialNumber=(string?)"R6-529", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(3), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=1, EventTypeId=3, EventSourceId=2, ExternalId=(string?)"DUPSEED-2010-B1",
                  DateOccurred="2026-08-13T10:41:00+00:00", Vehicle="2010-121 REL", Route="VR310",
                  Latitude=45.6205, Longitude=-122.6721, Address="1015 COLUMBIA ST, VANCOUVER, WA",
                  CustomerName="WATERFRONT COMMONS HOA", AccountNumber="2010-4462818",
                  BillArea=(string?)"068", BinSerialNumber=(string?)"R6-542", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(5), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=1, EventTypeId=3, EventSourceId=1, ExternalId=(string?)"DUPSEED-2010-B2",
                  DateOccurred="2026-08-13T10:44:00+00:00", Vehicle="2010-118 FEL", Route="VR310",
                  Latitude=45.6202, Longitude=-122.6719, Address="1015 COLUMBIA ST, VANCOUVER, WA",
                  CustomerName="WATERFRONT COMMONS HOA", AccountNumber="2010-4462818",
                  BillArea=(string?)"075", BinSerialNumber=(string?)"R6-555", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(6), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── Duplicate clusters — District 3 ──────────────────────────────
            new { DistrictId=3, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"DUPSEED-2012-A1",
                  DateOccurred="2026-08-14T09:27:00+00:00", Vehicle="2012-207 FEL", Route="BD102",
                  Latitude=44.0582, Longitude=-121.3011, Address="61249 S HWY 97, BEND, OR",
                  CustomerName="PONDEROSA PLAZA", AccountNumber="2012-5530417",
                  BillArea=(string?)"082", BinSerialNumber=(string?)"R6-568", Lob=(string?)"RESIDENTIAL",
                  Severity=(string?)"Severe", Quantity=(decimal?)2m,
                  ImageUrl=photo(2), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=3, EventTypeId=1, EventSourceId=2, ExternalId=(string?)"DUPSEED-2012-A2",
                  DateOccurred="2026-08-14T09:29:00+00:00", Vehicle="2012-211 FEL", Route="BD102",
                  Latitude=44.05845, Longitude=-121.3009, Address="61249 S HWY 97, BEND, OR",
                  CustomerName="PONDEROSA PLAZA", AccountNumber="2012-5530417",
                  BillArea=(string?)"089", BinSerialNumber=(string?)"R6-581", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Severe", Quantity=(decimal?)2m,
                  ImageUrl=photo(4), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            // ── Duplicate clusters — District 20 ─────────────────────────────
            new { DistrictId=20, EventTypeId=3, EventSourceId=1, ExternalId=(string?)"DUPSEED-5120-A1",
                  DateOccurred="2026-08-14T07:58:00+00:00", Vehicle="5120-2302 FEL", Route="NY605",
                  Latitude=29.7433, Longitude=-95.3921, Address="3800 SOUTHWEST FWY, HOUSTON, TX",
                  CustomerName="GREENWAY COMMONS", AccountNumber="5120-7791340",
                  BillArea=(string?)"096", BinSerialNumber=(string?)"R6-594", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(7), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=3, EventSourceId=2, ExternalId=(string?)"DUPSEED-5120-A2",
                  DateOccurred="2026-08-14T08:00:00+00:00", Vehicle="5120-2311 FEL", Route="NY605",
                  Latitude=29.7435, Longitude=-95.3918, Address="3800 SOUTHWEST FWY, HOUSTON, TX",
                  CustomerName="GREENWAY COMMONS", AccountNumber="5120-7791340",
                  BillArea=(string?)"013", BinSerialNumber=(string?)"R6-607", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(1), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=3, EventSourceId=1, ExternalId=(string?)"DUPSEED-5120-A3",
                  DateOccurred="2026-08-14T08:01:00+00:00", Vehicle="5120-2315 REL", Route="NY605",
                  Latitude=29.7431, Longitude=-95.392, Address="3800 SOUTHWEST FWY, HOUSTON, TX",
                  CustomerName="GREENWAY COMMONS", AccountNumber="5120-7791340",
                  BillArea=(string?)"020", BinSerialNumber=(string?)"R6-620", Lob=(string?)"RESIDENTIAL",
                  Severity=(string?)"Severe", Quantity=(decimal?)1m,
                  ImageUrl=photo(0), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=1, EventSourceId=2, ExternalId=(string?)"DUPSEED-5120-B1",
                  DateOccurred="2026-08-13T12:06:00+00:00", Vehicle="5120-2311 FEL", Route="RC201",
                  Latitude=29.8171, Longitude=-95.4009, Address="8820 AIRLINE DR, HOUSTON, TX",
                  CustomerName="AIRLINE FARMERS MARKET", AccountNumber="5120-7735602",
                  BillArea=(string?)"027", BinSerialNumber=(string?)"R6-633", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(4), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },

            new { DistrictId=20, EventTypeId=1, EventSourceId=1, ExternalId=(string?)"DUPSEED-5120-B2",
                  DateOccurred="2026-08-13T12:09:00+00:00", Vehicle="5120-2309 FEL", Route="RC201",
                  Latitude=29.8174, Longitude=-95.4011, Address="8820 AIRLINE DR, HOUSTON, TX",
                  CustomerName="AIRLINE FARMERS MARKET", AccountNumber="5120-7735602",
                  BillArea=(string?)"034", BinSerialNumber=(string?)"R6-646", Lob=(string?)"COMMERCIAL",
                  Severity=(string?)"Minimal", Quantity=(decimal?)1m,
                  ImageUrl=photo(2), ImageUrls=imgs([]),
                  EventStatus=0, DateClosed=(string?)null, ClosedBy=(string?)null },
        };

        foreach (var r in rows)
        {
            await conn.ExecuteAsync(sql, new
            {
                r.DistrictId, r.EventTypeId, r.EventSourceId, r.ExternalId,
                DateOccurred = DateTimeOffset.Parse(r.DateOccurred),
                r.Vehicle, r.Route, r.Latitude, r.Longitude,
                r.Address, r.CustomerName, r.AccountNumber,
                r.BillArea, r.BinSerialNumber, r.Lob,
                r.Severity, r.Quantity, r.ImageUrl, r.ImageUrls,
                r.EventStatus,
                DateClosed = r.DateClosed is null ? (DateTimeOffset?)null : DateTimeOffset.Parse(r.DateClosed),
                r.ClosedBy,
            });
        }
    }

    // ─── Event actions seed ───────────────────────────────────────────────────

    private static async Task SeedEventActionsAsync(SqlConnection conn)
    {
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM EventActions") > 0) return;

        // Map ExternalId → internal Id
        var extIdToId = (await conn.QueryAsync<(string? ExternalId, int Id)>(
            "SELECT ExternalId, Id FROM RouteEvents WHERE ExternalId IS NOT NULL"))
            .ToDictionary(r => r.ExternalId!, r => r.Id);

        int? Ev(string extId) => extIdToId.TryGetValue(extId, out var id) ? id : null;

        const string sql = @"
INSERT INTO EventActions
    (RouteEventId, ActionType, IsFinal, Notes, CloseReason,
     ServiceCodeId, ChargeAmount, ChargeQuantity,
     PaymentStatus, BilledAmount, BilledStatementNumber, CreatedBy, DateCreated)
VALUES
    (@RouteEventId, @ActionType, @IsFinal, @Notes, @CloseReason,
     @ServiceCodeId, @ChargeAmount, @ChargeQuantity,
     @PaymentStatus, @BilledAmount, @BilledStatementNumber, @CreatedBy, @DateCreated)";

        var actions = new[]
        {
            // Event 12225447 — open note
            new { ext="12225447", ActionType="note", IsFinal=false,
                  Notes=(string?)"Driver reported bags stacked beside container.", CloseReason=(string?)null,
                  ServiceCodeId=(int?)null, ChargeAmount=(decimal?)null, ChargeQuantity=(decimal?)null,
                  PaymentStatus=(string?)null, BilledAmount=(decimal?)null, BilledStatementNumber=(string?)null,
                  CreatedBy="Kyle.Patrick", DateCreated=DateTimeOffset.Parse("2026-08-05T03:51:12+00:00") },

            // Event 12225301 — charge (PAID)
            new { ext="12225301", ActionType="charge", IsFinal=true,
                  Notes=(string?)null, CloseReason=(string?)null,
                  ServiceCodeId=(int?)1, ChargeAmount=(decimal?)75m, ChargeQuantity=(decimal?)1m,
                  PaymentStatus=(string?)"PAID", BilledAmount=(decimal?)null, BilledStatementNumber=(string?)null,
                  CreatedBy="Kyle.Patrick", DateCreated=DateTimeOffset.Parse("2026-08-02T19:51:12+00:00") },

            // Event 12225281 — close
            new { ext="12225281", ActionType="close", IsFinal=true,
                  Notes=(string?)"Cart was set out late.", CloseReason=(string?)"No charge per driver/office",
                  ServiceCodeId=(int?)null, ChargeAmount=(decimal?)null, ChargeQuantity=(decimal?)null,
                  PaymentStatus=(string?)null, BilledAmount=(decimal?)null, BilledStatementNumber=(string?)null,
                  CreatedBy="Maria.Gonzalez", DateCreated=DateTimeOffset.Parse("2026-08-03T19:51:12+00:00") },

            // Event WV-90312 — close
            new { ext="WV-90312", ActionType="close", IsFinal=true,
                  Notes=(string?)"Lid closed on second review", CloseReason=(string?)"Not an Overfill",
                  ServiceCodeId=(int?)null, ChargeAmount=(decimal?)null, ChargeQuantity=(decimal?)null,
                  PaymentStatus=(string?)null, BilledAmount=(decimal?)null, BilledStatementNumber=(string?)null,
                  CreatedBy="Kyle.Patrick", DateCreated=DateTimeOffset.Parse("2026-08-12T16:14:59+00:00") },

            // Historical OJOS LOCOS charges (WV-8701, WV-8702, WV-8703)
            new { ext="WV-8701", ActionType="charge", IsFinal=true,
                  Notes=(string?)null, CloseReason=(string?)null,
                  ServiceCodeId=(int?)1, ChargeAmount=(decimal?)75m, ChargeQuantity=(decimal?)1m,
                  PaymentStatus=(string?)"PAID", BilledAmount=(decimal?)null, BilledStatementNumber=(string?)null,
                  CreatedBy="Kyle.Patrick", DateCreated=DateTimeOffset.Parse("2026-07-21T19:51:00+00:00") },

            new { ext="WV-8702", ActionType="charge", IsFinal=true,
                  Notes=(string?)null, CloseReason=(string?)null,
                  ServiceCodeId=(int?)1, ChargeAmount=(decimal?)125m, ChargeQuantity=(decimal?)1m,
                  PaymentStatus=(string?)"REFUNDED", BilledAmount=(decimal?)null, BilledStatementNumber=(string?)null,
                  CreatedBy="Kyle.Patrick", DateCreated=DateTimeOffset.Parse("2026-07-09T19:51:00+00:00") },

            new { ext="WV-8703", ActionType="charge", IsFinal=true,
                  Notes=(string?)null, CloseReason=(string?)null,
                  ServiceCodeId=(int?)1, ChargeAmount=(decimal?)75m, ChargeQuantity=(decimal?)1m,
                  PaymentStatus=(string?)"PAID", BilledAmount=(decimal?)null, BilledStatementNumber=(string?)null,
                  CreatedBy="Kyle.Patrick", DateCreated=DateTimeOffset.Parse("2026-06-27T19:51:00+00:00") },
        };

        foreach (var a in actions)
        {
            var eventId = Ev(a.ext);
            if (eventId is null) continue;

            await conn.ExecuteAsync(sql, new
            {
                RouteEventId = eventId,
                a.ActionType, a.IsFinal, a.Notes, a.CloseReason,
                a.ServiceCodeId, a.ChargeAmount, a.ChargeQuantity,
                a.PaymentStatus, a.BilledAmount, a.BilledStatementNumber,
                a.CreatedBy, a.DateCreated,
            });
        }
    }

    /// <summary>
    /// Promotes the logins listed under <c>Access:BootstrapAdmins</c> on every
    /// start. Re-applied each time rather than seeded once on purpose: it is the
    /// break-glass path back in if the last administrator is ever demoted, and a
    /// config edit plus a restart is the only recovery that does not need
    /// somebody with direct database access.
    /// </summary>
    public static async Task EnsureBootstrapAdminsAsync(
        string connectionString, IEnumerable<string> logins)
    {
        var wanted = logins
            .Where(l => !string.IsNullOrWhiteSpace(l))
            .Select(l => l.Trim())
            .ToList();

        if (wanted.Count == 0) return;

        await using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        foreach (var login in wanted)
        {
            // Match a domain-qualified login as well as a bare one: the config
            // says 352271, but IIS hands us WCI\352271 on the real servers and
            // both are the same person.
            await conn.ExecuteAsync(@"
UPDATE AppUsers
   SET Role = 'Admin', Active = 1
 WHERE ActiveDirectoryName = @login
    OR RIGHT(ActiveDirectoryName, LEN(@login) + 1) = '\' + @login;

IF @@ROWCOUNT = 0
INSERT INTO AppUsers (ActiveDirectoryName, Role, Active)
VALUES (@login, 'Admin', 1);", new { login });
        }
    }
}
