using Dapper;
using Microsoft.Data.SqlClient;

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

        await CreateTablesAsync(conn);
        await SeedLookupsAsync(conn);
        await SeedRouteEventsAsync(conn);
        await SeedEventActionsAsync(conn);
    }

    // ─── Schema ───────────────────────────────────────────────────────────────

    private static async Task CreateTablesAsync(SqlConnection conn)
    {
        // Tables must be created in FK-dependency order.
        await conn.ExecuteAsync(@"
IF OBJECT_ID('districts','U') IS NULL
CREATE TABLE districts (
    id             INT            IDENTITY(1,1) PRIMARY KEY,
    number         NVARCHAR(50)   NOT NULL,
    name           NVARCHAR(255)  NOT NULL,
    region         NVARCHAR(100)  NOT NULL,
    hauling_system INT            NULL,
    active         BIT            NOT NULL DEFAULT 1
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('event_types','U') IS NULL
CREATE TABLE event_types (
    id     INT           IDENTITY(1,1) PRIMARY KEY,
    name   NVARCHAR(255) NOT NULL,
    active BIT           NOT NULL DEFAULT 1
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('event_sources','U') IS NULL
CREATE TABLE event_sources (
    id     INT           IDENTITY(1,1) PRIMARY KEY,
    name   NVARCHAR(255) NOT NULL,
    active BIT           NOT NULL DEFAULT 1
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('service_codes','U') IS NULL
CREATE TABLE service_codes (
    id          INT            IDENTITY(1,1) PRIMARY KEY,
    district_id INT            NOT NULL REFERENCES districts(id),
    code        NVARCHAR(50)   NOT NULL,
    description NVARCHAR(500)  NOT NULL,
    amount      DECIMAL(12,4)  NOT NULL,
    active      BIT            NOT NULL DEFAULT 1
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('account_flags','U') IS NULL
CREATE TABLE account_flags (
    id             INT              IDENTITY(1,1) PRIMARY KEY,
    district_id    INT              NOT NULL REFERENCES districts(id),
    account_number NVARCHAR(50)     NOT NULL,
    flag           NVARCHAR(100)    NOT NULL DEFAULT 'contract_no_overages',
    created_by     NVARCHAR(100)    NOT NULL,
    date_created   DATETIMEOFFSET   NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_account_flags_district_account_flag
        UNIQUE (district_id, account_number, flag)
);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('route_events','U') IS NULL
CREATE TABLE route_events (
    id               INT              IDENTITY(1,1) PRIMARY KEY,
    district_id      INT              NOT NULL REFERENCES districts(id),
    event_type_id    INT              NOT NULL REFERENCES event_types(id),
    event_source_id  INT              NOT NULL REFERENCES event_sources(id),
    external_id      NVARCHAR(100)    NULL,
    date_occurred    DATETIMEOFFSET   NOT NULL,
    vehicle          NVARCHAR(100)    NOT NULL,
    route            NVARCHAR(50)     NOT NULL,
    latitude         FLOAT            NOT NULL,
    longitude        FLOAT            NOT NULL,
    address          NVARCHAR(500)    NOT NULL,
    customer_name    NVARCHAR(255)    NOT NULL,
    account_number   NVARCHAR(50)     NOT NULL,
    bill_area        NVARCHAR(100)    NULL,
    bin_serial_number NVARCHAR(100)   NULL,
    lob              NVARCHAR(100)    NULL,
    rmo_status       NVARCHAR(100)    NULL,
    details          NVARCHAR(MAX)    NULL,
    stop             NVARCHAR(50)     NULL,
    work_order_number NVARCHAR(100)   NULL,
    tablet_notes     NVARCHAR(MAX)    NULL,
    quantity         DECIMAL(9,2)     NULL,
    image_url        NVARCHAR(500)    NULL,
    image_urls       NVARCHAR(MAX)    NOT NULL DEFAULT '[]',
    severity         NVARCHAR(50)     NULL,
    customer_since   DATETIMEOFFSET   NULL,
    event_status     INT              NOT NULL DEFAULT 0,
    date_closed      DATETIMEOFFSET   NULL,
    closed_by        NVARCHAR(100)    NULL,
    customer_routes  NVARCHAR(MAX)    NOT NULL DEFAULT '[]'
);");

        await conn.ExecuteAsync(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='route_events_account_date_idx')
    CREATE INDEX route_events_account_date_idx ON route_events(account_number, date_occurred);");

        await conn.ExecuteAsync(@"
IF OBJECT_ID('event_actions','U') IS NULL
CREATE TABLE event_actions (
    id                      INT              IDENTITY(1,1) PRIMARY KEY,
    route_event_id          INT              NOT NULL REFERENCES route_events(id),
    action_type             NVARCHAR(50)     NOT NULL,
    is_final                BIT              NOT NULL DEFAULT 0,
    notes                   NVARCHAR(MAX)    NULL,
    close_reason            NVARCHAR(255)    NULL,
    service_code_id         INT              NULL REFERENCES service_codes(id),
    charge_amount           DECIMAL(12,4)    NULL,
    charge_quantity         DECIMAL(9,2)     NULL,
    billed_statement_number NVARCHAR(100)    NULL,
    payment_status          NVARCHAR(50)     NULL,
    billed_amount           DECIMAL(12,4)    NULL,
    created_by              NVARCHAR(100)    NOT NULL,
    date_created            DATETIMEOFFSET   NOT NULL DEFAULT SYSDATETIMEOFFSET()
);");

        await conn.ExecuteAsync(@"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='event_actions_route_event_idx')
    CREATE INDEX event_actions_route_event_idx ON event_actions(route_event_id);");
    }

    // ─── Lookup seed data ─────────────────────────────────────────────────────

    private static async Task SeedLookupsAsync(SqlConnection conn)
    {
        // event_types
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM event_types") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT event_types ON;
INSERT INTO event_types (id, name, active) VALUES
  (1, 'Extra', 1),
  (2, 'Contamination', 1),
  (3, 'Overloaded', 1),
  (4, 'Blocked Container', 1),
  (5, 'Not Out', 1);
SET IDENTITY_INSERT event_types OFF;");
        }

        // event_sources
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM event_sources") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT event_sources ON;
INSERT INTO event_sources (id, name, active) VALUES
  (1, 'WasteVision', 1),
  (2, '3rd Eye', 1),
  (3, 'Manual', 1);
SET IDENTITY_INSERT event_sources OFF;");
        }

        // districts
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM districts") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT districts ON;
INSERT INTO districts (id, number, name, region, hauling_system, active) VALUES
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
SET IDENTITY_INSERT districts OFF;");
        }

        // service_codes
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM service_codes") == 0)
        {
            await conn.ExecuteAsync(@"
SET IDENTITY_INSERT service_codes ON;
INSERT INTO service_codes (id, district_id, code, description, amount, active) VALUES
  (1, 20, 'EXTRA-COM', 'Extra pickup - Commercial ** Prefer RMO **', 75.0000, 1),
  (2, 20, 'EXTRA-RES', 'Extra pickup - Residential',                 35.0000, 1),
  (3, 20, 'CONTAM',    'Contamination charge',                       95.0000, 1),
  (4, 20, 'OVERLOAD',  'Overloaded container charge',                65.0000, 1),
  (5, 20, 'GATE',      'Gate / access fee',                          15.0000, 1),
  (6,  1, 'EXTRA-COM', 'Extra pickup - Commercial',                  70.0000, 1),
  (7,  1, 'CONTAM',    'Contamination charge',                       90.0000, 1),
  (8,  1, 'OVERLOAD',  'Overloaded container charge',                60.0000, 1);
SET IDENTITY_INSERT service_codes OFF;");
        }
    }

    // ─── Route events seed ────────────────────────────────────────────────────

    private static async Task SeedRouteEventsAsync(SqlConnection conn)
    {
        // Skip entirely if events already exist
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM route_events") > 0) return;

        const string sql = @"
INSERT INTO route_events
    (district_id, event_type_id, event_source_id, external_id,
     date_occurred, vehicle, route, latitude, longitude,
     address, customer_name, account_number,
     bill_area, bin_serial_number, lob, severity, quantity,
     image_url, image_urls,
     event_status, date_closed, closed_by)
VALUES
    (@district_id, @event_type_id, @event_source_id, @external_id,
     @date_occurred, @vehicle, @route, @latitude, @longitude,
     @address, @customer_name, @account_number,
     @bill_area, @bin_serial_number, @lob, @severity, @quantity,
     @image_url, @image_urls,
     @event_status, @date_closed, @closed_by)";

        var imgs = new Func<int[], string>(ids =>
            ids.Length == 0 ? "[]"
            : "[" + string.Join(",", ids.Select(n => $"\"/event-photos/truck-cam-{n}.jpg\"")) + "]");
        var photo = new Func<int, string?>(n => n == 0 ? null : $"/event-photos/truck-cam-{n}.jpg");

        var rows = new[]
        {
            // ── District 20 (Texas) ──────────────────────────────────────────
            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"12225447",
                  date_occurred="2026-08-04T19:51:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.991, longitude=-95.4227, address="15155 NORTH FREEWAY, HOUSTON, TX",
                  customer_name="OJOS LOCOS NORTH FWY", account_number="5120-7786202",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"BIN-88231", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([2,3,1,4,5]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"12225512",
                  date_occurred="2026-08-05T13:51:00+00:00", vehicle="5120-2311 FEL", route="NY305",
                  latitude=29.7604, longitude=-95.3698, address="2401 MAIN ST, HOUSTON, TX",
                  customer_name="LONE STAR CANTINA", account_number="5120-7712045",
                  bill_area=(string?)"HARRIS/MTA Z2", bin_serial_number=(string?)"BIN-77120", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)2m,
                  image_url=photo(4), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=2, event_source_id=1, external_id=(string?)"12225533",
                  date_occurred="2026-08-05T23:51:00+00:00", vehicle="5120-2315 REL", route="RC201",
                  latitude=29.8168, longitude=-95.4012, address="8800 AIRLINE DR, HOUSTON, TX",
                  customer_name="PARK TRAILS APARTMENTS", account_number="5120-7734411",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"BIN-90112", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(5), image_urls=imgs([6,7,1,2,3]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=3, event_source_id=2, external_id=(string?)"12225390",
                  date_occurred="2026-08-03T19:51:00+00:00", vehicle="5120-2302 FEL", route="NY605",
                  latitude=29.737, longitude=-95.4613, address="5900 WESTHEIMER RD, HOUSTON, TX",
                  customer_name="GALLERIA FOOD COURT", account_number="5120-7701993",
                  bill_area=(string?)"HARRIS/MTA Z1", bin_serial_number=(string?)"BIN-66102", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(2), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=5, event_source_id=3, external_id=(string?)"12225281",
                  date_occurred="2026-08-02T19:51:00+00:00", vehicle="5120-2408 RSL", route="RS114",
                  latitude=29.92, longitude=-95.21, address="12207 EAST LAKE DR, HUMBLE, TX",
                  customer_name="THOMPSON, MARGARET", account_number="5120-7642210",
                  bill_area=(string?)"HARRIS/RES Z6", bin_serial_number=(string?)null, lob=(string?)"Residential",
                  severity=(string?)"Minimal", quantity=(decimal?)3m,
                  image_url=photo(0), image_urls=imgs([]),
                  event_status=1, date_closed=(string?)"2026-08-03T19:51:00+00:00", closed_by=(string?)"Maria.Gonzalez" },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"12225301",
                  date_occurred="2026-08-01T19:51:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.9955, longitude=-95.415, address="202 RICHEY RD, HOUSTON, TX",
                  customer_name="NORTH FWY TRUCK STOP", account_number="5120-7688109",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"BIN-55020", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(3), image_urls=imgs([]),
                  event_status=1, date_closed=(string?)"2026-08-02T19:51:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            // ── District 1 (Vancouver) ───────────────────────────────────────
            new { district_id=1, event_type_id=1, event_source_id=1, external_id=(string?)"88110234",
                  date_occurred="2026-08-05T19:51:00+00:00", vehicle="2010-118 FEL", route="VA204",
                  latitude=45.6387, longitude=-122.6615, address="7720 NE VANCOUVER MALL DR, VANCOUVER, WA",
                  customer_name="CASCADE STATION RETAIL", account_number="2010-4410092",
                  bill_area=(string?)"CLARK Z2", bin_serial_number=(string?)"BIN-20115", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(6), image_urls=imgs([1,2,3,4]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=1, event_type_id=2, event_source_id=2, external_id=(string?)"88110301",
                  date_occurred="2026-08-04T19:51:00+00:00", vehicle="2010-121 REL", route="VR310",
                  latitude=45.628, longitude=-122.674, address="3311 MAIN ST, VANCOUVER, WA",
                  customer_name="UPTOWN LOFTS", account_number="2010-4433001",
                  bill_area=(string?)"CLARK Z1", bin_serial_number=(string?)"BIN-31200", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(0), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── District 20 (WV/nearby cluster area) ────────────────────────
            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"WV-90311",
                  date_occurred="2026-08-04T19:55:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.9922, longitude=-95.4219, address="4415 NORTH FWY",
                  customer_name="NORTH FWY PLAZA", account_number="5120-7786455",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-217", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(7), image_urls=imgs([4,1,2,3]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"WV-90312",
                  date_occurred="2026-08-04T19:44:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.9901, longitude=-95.4212, address="4380 NORTH FWY",
                  customer_name="FWY SELF STORAGE", account_number="5120-7786990",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-230", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(5), image_urls=imgs([]),
                  event_status=1, date_closed=(string?)"2026-08-12T16:14:39+00:00", closed_by=(string?)"Kyle.Patrick" },

            // ── District 20 — closed historical events ───────────────────────
            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"WV-8701",
                  date_occurred="2026-07-20T19:51:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.991, longitude=-95.4227, address="15155 NORTH FREEWAY, HOUSTON, TX",
                  customer_name="OJOS LOCOS NORTH FWY", account_number="5120-7786202",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-243", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(0), image_urls=imgs([]),
                  event_status=1, date_closed=(string?)"2026-07-21T19:51:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"WV-8702",
                  date_occurred="2026-07-08T19:51:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.991, longitude=-95.4227, address="15155 NORTH FREEWAY, HOUSTON, TX",
                  customer_name="OJOS LOCOS NORTH FWY", account_number="5120-7786202",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-256", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([]),
                  event_status=1, date_closed=(string?)"2026-07-09T19:51:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"WV-8703",
                  date_occurred="2026-06-26T19:51:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.991, longitude=-95.4227, address="15155 NORTH FREEWAY, HOUSTON, TX",
                  customer_name="OJOS LOCOS NORTH FWY", account_number="5120-7786202",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-269", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(7), image_urls=imgs([2,5,1,3,4]),
                  event_status=1, date_closed=(string?)"2026-06-27T19:51:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"WV-90312-B",
                  date_occurred="2026-08-04T19:38:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.993, longitude=-95.4215, address="4419 NORTH FWY",
                  customer_name="FWY PLAZA SUITE B", account_number="5120-7786460",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-282", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(2), image_urls=imgs([2,1,3,4]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=2, event_source_id=1, external_id=(string?)"WV-90313",
                  date_occurred="2026-08-04T20:12:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.9916, longitude=-95.4226, address="4403 NORTH FWY",
                  customer_name="NORTH FWY STORAGE", account_number="5120-7786472",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-295", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(3), image_urls=imgs([3,1,2,4]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"WV-90314",
                  date_occurred="2026-08-04T19:47:00+00:00", vehicle="5120-2309 FEL", route="NY109",
                  latitude=29.9925, longitude=-95.421, address="4421 NORTH FWY",
                  customer_name="PLAZA DELI & MARKET", account_number="5120-7786481",
                  bill_area=(string?)"HARRIS/MTA Z4", bin_serial_number=(string?)"R6-308", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(5), image_urls=imgs([5,1,2,3]),
                  event_status=1, date_closed=(string?)"2026-08-04T21:30:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            // ── District 15 (Rogue Disposal) ─────────────────────────────────
            new { district_id=15, event_type_id=3, event_source_id=3, external_id=(string?)"WV-88200000",
                  date_occurred="2026-08-09T12:09:00+00:00", vehicle="2010-2134 REL", route="SW502",
                  latitude=44.1472, longitude=-122.5474, address="5039 OAK ST",
                  customer_name="RIVERSIDE APARTMENTS", account_number="2010-7689491",
                  bill_area=(string?)"ZONE 2", bin_serial_number=(string?)"R6-321", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(2), image_urls=imgs([2,4,5]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=15, event_type_id=1, event_source_id=2, external_id=(string?)"WV-88200001",
                  date_occurred="2026-08-10T16:48:00+00:00", vehicle="2010-2392 FEL", route="VA550",
                  latitude=44.69, longitude=-121.3281, address="1574 MAIN ST",
                  customer_name="MAPLE ST DINER", account_number="2010-7242480",
                  bill_area=(string?)"ZONE 1", bin_serial_number=(string?)"R6-334", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(3), image_urls=imgs([3,4,6]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── District 3 (Cascade Disposal) ────────────────────────────────
            new { district_id=3, event_type_id=3, event_source_id=3, external_id=(string?)"WV-88200002",
                  date_occurred="2026-08-05T13:24:00+00:00", vehicle="2010-2129 ASL", route="SW397",
                  latitude=44.0677, longitude=-121.4858, address="1767 OAK ST",
                  customer_name="GRANDVIEW MEDICAL", account_number="2010-7889166",
                  bill_area=(string?)"ZONE 4", bin_serial_number=(string?)"R6-347", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([1,2,3]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=15, event_type_id=4, event_source_id=2, external_id=(string?)"WV-88200003",
                  date_occurred="2026-08-02T11:04:00+00:00", vehicle="2010-2397 REL", route="VA265",
                  latitude=46.7133, longitude=-122.3148, address="6658 HARBOR DR",
                  customer_name="CEDAR MILL LOFTS", account_number="2010-7197496",
                  bill_area=(string?)"ZONE 2", bin_serial_number=(string?)"R6-360", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([1,7,6,5]),
                  event_status=1, date_closed=(string?)"2026-08-02T22:00:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            new { district_id=1, event_type_id=3, event_source_id=3, external_id=(string?)"WV-88200004",
                  date_occurred="2026-08-10T17:10:00+00:00", vehicle="2010-2264 REL", route="NY289",
                  latitude=44.0955, longitude=-122.5136, address="4283 SE FOSTER RD",
                  customer_name="SUNSET STRIP MALL", account_number="2010-7700892",
                  bill_area=(string?)"ZONE 4", bin_serial_number=(string?)"R6-373", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(2), image_urls=imgs([2,3]),
                  event_status=1, date_closed=(string?)"2026-08-10T22:00:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            // ── District 17 (Tacoma Hauling) ─────────────────────────────────
            new { district_id=17, event_type_id=5, event_source_id=2, external_id=(string?)"WV-88200005",
                  date_occurred="2026-08-12T12:34:00+00:00", vehicle="2010-2155 ASL", route="VA109",
                  latitude=46.6916, longitude=-121.3529, address="2041 NE BROADWAY",
                  customer_name="HARBOR SEAFOOD CO", account_number="2010-7146485",
                  bill_area=(string?)"ZONE 1", bin_serial_number=(string?)"R6-386", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(5), image_urls=imgs([5,3,4,2,6]),
                  event_status=1, date_closed=(string?)"2026-08-12T22:00:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            // ── District 1 — open events ─────────────────────────────────────
            new { district_id=1, event_type_id=5, event_source_id=3, external_id=(string?)"WV-88200006",
                  date_occurred="2026-08-09T10:37:00+00:00", vehicle="2010-2355 REL", route="VA420",
                  latitude=46.4755, longitude=-121.6684, address="1824 HARBOR DR",
                  customer_name="PIONEER SQUARE OFFICES", account_number="2010-7649511",
                  bill_area=(string?)"ZONE 3", bin_serial_number=(string?)"R6-399", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(4), image_urls=imgs([4,6,5]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── District 17 — open ───────────────────────────────────────────
            new { district_id=17, event_type_id=2, event_source_id=2, external_id=(string?)"WV-88200007",
                  date_occurred="2026-08-01T06:31:00+00:00", vehicle="2010-2287 ASL", route="VA552",
                  latitude=44.9031, longitude=-122.3055, address="8556 OAK ST",
                  customer_name="EASTSIDE AUTO PARTS", account_number="2010-7354264",
                  bill_area=(string?)"ZONE 4", bin_serial_number=(string?)"R6-412", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([1,2]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── District 1 — closed ──────────────────────────────────────────
            new { district_id=1, event_type_id=4, event_source_id=3, external_id=(string?)"WV-88200008",
                  date_occurred="2026-08-09T07:55:00+00:00", vehicle="2010-2218 FEL", route="VA527",
                  latitude=44.7979, longitude=-121.6767, address="8460 SE FOSTER RD",
                  customer_name="BLUE HERON BREWERY", account_number="2010-7884808",
                  bill_area=(string?)"ZONE 2", bin_serial_number=(string?)"R6-425", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(6), image_urls=imgs([6,1,4,5]),
                  event_status=1, date_closed=(string?)"2026-08-09T22:00:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            // ── District 3 — open ────────────────────────────────────────────
            new { district_id=3, event_type_id=3, event_source_id=1, external_id=(string?)"WV-88200009",
                  date_occurred="2026-08-04T14:45:00+00:00", vehicle="2010-2272 FEL", route="VA483",
                  latitude=46.7109, longitude=-122.6036, address="7561 HARBOR DR",
                  customer_name="WILLAMETTE STORAGE", account_number="2010-7605538",
                  bill_area=(string?)"ZONE 1", bin_serial_number=(string?)"R6-438", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(2), image_urls=imgs([2,6,3]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── District 20 — closed ─────────────────────────────────────────
            new { district_id=20, event_type_id=2, event_source_id=2, external_id=(string?)"WV-88200010",
                  date_occurred="2026-08-05T11:07:00+00:00", vehicle="5120-2122 ASL", route="NY293",
                  latitude=46.7849, longitude=-121.3825, address="7318 HARBOR DR",
                  customer_name="OAKRIDGE ELEMENTARY", account_number="5120-7281391",
                  bill_area=(string?)"ZONE 1", bin_serial_number=(string?)"R6-451", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([1,7]),
                  event_status=1, date_closed=(string?)"2026-08-05T22:00:00+00:00", closed_by=(string?)"Kyle.Patrick" },

            // ── District 3 — open ────────────────────────────────────────────
            new { district_id=3, event_type_id=5, event_source_id=3, external_id=(string?)"WV-88200011",
                  date_occurred="2026-08-07T11:25:00+00:00", vehicle="2010-2378 ASL", route="NY557",
                  latitude=44.0304, longitude=-121.7097, address="3716 MAIN ST",
                  customer_name="PACIFIC CREST GYM", account_number="2010-7328774",
                  bill_area=(string?)"ZONE 3", bin_serial_number=(string?)"R6-464", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(6), image_urls=imgs([6,4,1,2]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── District 17 — open ───────────────────────────────────────────
            new { district_id=17, event_type_id=5, event_source_id=2, external_id=(string?)"WV-88200012",
                  date_occurred="2026-08-11T09:59:00+00:00", vehicle="2010-2239 REL", route="NY137",
                  latitude=46.5642, longitude=-121.8589, address="3392 NE BROADWAY",
                  customer_name="TIMBERLINE HARDWARE", account_number="2010-7183777",
                  bill_area=(string?)"ZONE 1", bin_serial_number=(string?)"R6-477", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([1,5,4]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── District 1 — open ────────────────────────────────────────────
            new { district_id=1, event_type_id=5, event_source_id=1, external_id=(string?)"WV-88200013",
                  date_occurred="2026-08-06T16:26:00+00:00", vehicle="2010-2262 FEL", route="SW186",
                  latitude=46.26, longitude=-121.4862, address="7774 OAK ST",
                  customer_name="FOSTER RD LAUNDRY", account_number="2010-7827457",
                  bill_area=(string?)"ZONE 4", bin_serial_number=(string?)"R6-490", lob=(string?)"Commercial",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(2), image_urls=imgs([2,1,7]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=1, event_type_id=1, event_source_id=1, external_id=(string?)"WV-88200014",
                  date_occurred="2026-08-05T17:52:00+00:00", vehicle="2010-2265 ASL", route="NY581",
                  latitude=45.6984, longitude=-122.3003, address="3610 CEDAR BLVD",
                  customer_name="KLICKITAT MARKET", account_number="2010-7573938",
                  bill_area=(string?)"ZONE 1", bin_serial_number=(string?)"R6-503", lob=(string?)"Commercial",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(4), image_urls=imgs([4,3,1,7,6]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── Duplicate clusters — District 1 ──────────────────────────────
            new { district_id=1, event_type_id=1, event_source_id=1, external_id=(string?)"DUPSEED-2010-A1",
                  date_occurred="2026-08-14T08:12:00+00:00", vehicle="2010-118 FEL", route="VA204",
                  latitude=45.6339, longitude=-122.6031, address="11505 NE FOURTH PLAIN BLVD, VANCOUVER, WA",
                  customer_name="ORCHARDS MARKET CENTER", account_number="2010-4451220",
                  bill_area=(string?)"054", bin_serial_number=(string?)"R6-516", lob=(string?)"RESIDENTIAL",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=1, event_type_id=1, event_source_id=2, external_id=(string?)"DUPSEED-2010-A2",
                  date_occurred="2026-08-14T08:14:00+00:00", vehicle="2010-121 REL", route="VA204",
                  latitude=45.6341, longitude=-122.6032, address="11505 NE FOURTH PLAIN BLVD, VANCOUVER, WA",
                  customer_name="ORCHARDS MARKET CENTER", account_number="2010-4451220",
                  bill_area=(string?)"061", bin_serial_number=(string?)"R6-529", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(3), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=1, event_type_id=3, event_source_id=2, external_id=(string?)"DUPSEED-2010-B1",
                  date_occurred="2026-08-13T10:41:00+00:00", vehicle="2010-121 REL", route="VR310",
                  latitude=45.6205, longitude=-122.6721, address="1015 COLUMBIA ST, VANCOUVER, WA",
                  customer_name="WATERFRONT COMMONS HOA", account_number="2010-4462818",
                  bill_area=(string?)"068", bin_serial_number=(string?)"R6-542", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(5), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=1, event_type_id=3, event_source_id=1, external_id=(string?)"DUPSEED-2010-B2",
                  date_occurred="2026-08-13T10:44:00+00:00", vehicle="2010-118 FEL", route="VR310",
                  latitude=45.6202, longitude=-122.6719, address="1015 COLUMBIA ST, VANCOUVER, WA",
                  customer_name="WATERFRONT COMMONS HOA", account_number="2010-4462818",
                  bill_area=(string?)"075", bin_serial_number=(string?)"R6-555", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(6), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── Duplicate clusters — District 3 ──────────────────────────────
            new { district_id=3, event_type_id=1, event_source_id=1, external_id=(string?)"DUPSEED-2012-A1",
                  date_occurred="2026-08-14T09:27:00+00:00", vehicle="2012-207 FEL", route="BD102",
                  latitude=44.0582, longitude=-121.3011, address="61249 S HWY 97, BEND, OR",
                  customer_name="PONDEROSA PLAZA", account_number="2012-5530417",
                  bill_area=(string?)"082", bin_serial_number=(string?)"R6-568", lob=(string?)"RESIDENTIAL",
                  severity=(string?)"Severe", quantity=(decimal?)2m,
                  image_url=photo(2), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=3, event_type_id=1, event_source_id=2, external_id=(string?)"DUPSEED-2012-A2",
                  date_occurred="2026-08-14T09:29:00+00:00", vehicle="2012-211 FEL", route="BD102",
                  latitude=44.05845, longitude=-121.3009, address="61249 S HWY 97, BEND, OR",
                  customer_name="PONDEROSA PLAZA", account_number="2012-5530417",
                  bill_area=(string?)"089", bin_serial_number=(string?)"R6-581", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Severe", quantity=(decimal?)2m,
                  image_url=photo(4), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            // ── Duplicate clusters — District 20 ─────────────────────────────
            new { district_id=20, event_type_id=3, event_source_id=1, external_id=(string?)"DUPSEED-5120-A1",
                  date_occurred="2026-08-14T07:58:00+00:00", vehicle="5120-2302 FEL", route="NY605",
                  latitude=29.7433, longitude=-95.3921, address="3800 SOUTHWEST FWY, HOUSTON, TX",
                  customer_name="GREENWAY COMMONS", account_number="5120-7791340",
                  bill_area=(string?)"096", bin_serial_number=(string?)"R6-594", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(7), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=3, event_source_id=2, external_id=(string?)"DUPSEED-5120-A2",
                  date_occurred="2026-08-14T08:00:00+00:00", vehicle="5120-2311 FEL", route="NY605",
                  latitude=29.7435, longitude=-95.3918, address="3800 SOUTHWEST FWY, HOUSTON, TX",
                  customer_name="GREENWAY COMMONS", account_number="5120-7791340",
                  bill_area=(string?)"013", bin_serial_number=(string?)"R6-607", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(1), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=3, event_source_id=1, external_id=(string?)"DUPSEED-5120-A3",
                  date_occurred="2026-08-14T08:01:00+00:00", vehicle="5120-2315 REL", route="NY605",
                  latitude=29.7431, longitude=-95.392, address="3800 SOUTHWEST FWY, HOUSTON, TX",
                  customer_name="GREENWAY COMMONS", account_number="5120-7791340",
                  bill_area=(string?)"020", bin_serial_number=(string?)"R6-620", lob=(string?)"RESIDENTIAL",
                  severity=(string?)"Severe", quantity=(decimal?)1m,
                  image_url=photo(0), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=1, event_source_id=2, external_id=(string?)"DUPSEED-5120-B1",
                  date_occurred="2026-08-13T12:06:00+00:00", vehicle="5120-2311 FEL", route="RC201",
                  latitude=29.8171, longitude=-95.4009, address="8820 AIRLINE DR, HOUSTON, TX",
                  customer_name="AIRLINE FARMERS MARKET", account_number="5120-7735602",
                  bill_area=(string?)"027", bin_serial_number=(string?)"R6-633", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(4), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },

            new { district_id=20, event_type_id=1, event_source_id=1, external_id=(string?)"DUPSEED-5120-B2",
                  date_occurred="2026-08-13T12:09:00+00:00", vehicle="5120-2309 FEL", route="RC201",
                  latitude=29.8174, longitude=-95.4011, address="8820 AIRLINE DR, HOUSTON, TX",
                  customer_name="AIRLINE FARMERS MARKET", account_number="5120-7735602",
                  bill_area=(string?)"034", bin_serial_number=(string?)"R6-646", lob=(string?)"COMMERCIAL",
                  severity=(string?)"Minimal", quantity=(decimal?)1m,
                  image_url=photo(2), image_urls=imgs([]),
                  event_status=0, date_closed=(string?)null, closed_by=(string?)null },
        };

        foreach (var r in rows)
        {
            await conn.ExecuteAsync(sql, new
            {
                r.district_id, r.event_type_id, r.event_source_id, r.external_id,
                date_occurred = DateTimeOffset.Parse(r.date_occurred),
                r.vehicle, r.route, r.latitude, r.longitude,
                r.address, r.customer_name, r.account_number,
                r.bill_area, r.bin_serial_number, r.lob,
                r.severity, r.quantity, r.image_url, r.image_urls,
                r.event_status,
                date_closed = r.date_closed is null ? (DateTimeOffset?)null : DateTimeOffset.Parse(r.date_closed),
                r.closed_by,
            });
        }
    }

    // ─── Event actions seed ───────────────────────────────────────────────────

    private static async Task SeedEventActionsAsync(SqlConnection conn)
    {
        if (await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM event_actions") > 0) return;

        // Map external_id → internal id
        var extIdToId = (await conn.QueryAsync<(string? ExternalId, int Id)>(
            "SELECT external_id, id FROM route_events WHERE external_id IS NOT NULL"))
            .ToDictionary(r => r.ExternalId!, r => r.Id);

        int? Ev(string extId) => extIdToId.TryGetValue(extId, out var id) ? id : null;

        const string sql = @"
INSERT INTO event_actions
    (route_event_id, action_type, is_final, notes, close_reason,
     service_code_id, charge_amount, charge_quantity,
     payment_status, billed_amount, billed_statement_number, created_by, date_created)
VALUES
    (@route_event_id, @action_type, @is_final, @notes, @close_reason,
     @service_code_id, @charge_amount, @charge_quantity,
     @payment_status, @billed_amount, @billed_statement_number, @created_by, @date_created)";

        var actions = new[]
        {
            // Event 12225447 — open note
            new { ext="12225447", action_type="note", is_final=false,
                  notes=(string?)"Driver reported bags stacked beside container.", close_reason=(string?)null,
                  service_code_id=(int?)null, charge_amount=(decimal?)null, charge_quantity=(decimal?)null,
                  payment_status=(string?)null, billed_amount=(decimal?)null, billed_statement_number=(string?)null,
                  created_by="Kyle.Patrick", date_created=DateTimeOffset.Parse("2026-08-05T03:51:12+00:00") },

            // Event 12225301 — charge (PAID)
            new { ext="12225301", action_type="charge", is_final=true,
                  notes=(string?)null, close_reason=(string?)null,
                  service_code_id=(int?)1, charge_amount=(decimal?)75m, charge_quantity=(decimal?)1m,
                  payment_status=(string?)"PAID", billed_amount=(decimal?)null, billed_statement_number=(string?)null,
                  created_by="Kyle.Patrick", date_created=DateTimeOffset.Parse("2026-08-02T19:51:12+00:00") },

            // Event 12225281 — close
            new { ext="12225281", action_type="close", is_final=true,
                  notes=(string?)"Cart was set out late.", close_reason=(string?)"No charge per driver/office",
                  service_code_id=(int?)null, charge_amount=(decimal?)null, charge_quantity=(decimal?)null,
                  payment_status=(string?)null, billed_amount=(decimal?)null, billed_statement_number=(string?)null,
                  created_by="Maria.Gonzalez", date_created=DateTimeOffset.Parse("2026-08-03T19:51:12+00:00") },

            // Event WV-90312 — close
            new { ext="WV-90312", action_type="close", is_final=true,
                  notes=(string?)"Lid closed on second review", close_reason=(string?)"Not an Overfill",
                  service_code_id=(int?)null, charge_amount=(decimal?)null, charge_quantity=(decimal?)null,
                  payment_status=(string?)null, billed_amount=(decimal?)null, billed_statement_number=(string?)null,
                  created_by="Kyle.Patrick", date_created=DateTimeOffset.Parse("2026-08-12T16:14:59+00:00") },

            // Historical OJOS LOCOS charges (WV-8701, WV-8702, WV-8703)
            new { ext="WV-8701", action_type="charge", is_final=true,
                  notes=(string?)null, close_reason=(string?)null,
                  service_code_id=(int?)1, charge_amount=(decimal?)75m, charge_quantity=(decimal?)1m,
                  payment_status=(string?)"PAID", billed_amount=(decimal?)null, billed_statement_number=(string?)null,
                  created_by="Kyle.Patrick", date_created=DateTimeOffset.Parse("2026-07-21T19:51:00+00:00") },

            new { ext="WV-8702", action_type="charge", is_final=true,
                  notes=(string?)null, close_reason=(string?)null,
                  service_code_id=(int?)1, charge_amount=(decimal?)125m, charge_quantity=(decimal?)1m,
                  payment_status=(string?)"REFUNDED", billed_amount=(decimal?)null, billed_statement_number=(string?)null,
                  created_by="Kyle.Patrick", date_created=DateTimeOffset.Parse("2026-07-09T19:51:00+00:00") },

            new { ext="WV-8703", action_type="charge", is_final=true,
                  notes=(string?)null, close_reason=(string?)null,
                  service_code_id=(int?)1, charge_amount=(decimal?)75m, charge_quantity=(decimal?)1m,
                  payment_status=(string?)"PAID", billed_amount=(decimal?)null, billed_statement_number=(string?)null,
                  created_by="Kyle.Patrick", date_created=DateTimeOffset.Parse("2026-06-27T19:51:00+00:00") },
        };

        foreach (var a in actions)
        {
            var eventId = Ev(a.ext);
            if (eventId is null) continue;

            await conn.ExecuteAsync(sql, new
            {
                route_event_id = eventId,
                a.action_type, a.is_final, a.notes, a.close_reason,
                a.service_code_id, a.charge_amount, a.charge_quantity,
                a.payment_status, a.billed_amount, a.billed_statement_number,
                a.created_by, a.date_created,
            });
        }
    }
}
