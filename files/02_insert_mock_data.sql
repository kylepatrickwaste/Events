-- ============================================================
-- 02_insert_mock_data.sql
-- Microsoft SQL Server  —  Route Events mock data seed
--
-- Populates all lookup tables and inserts the full demo dataset:
--   • EventTypes (5 rows), EventSources (4 rows)
--   • Districts (4 rows — Vancouver/2010, Vancouver-Minimal/2010-M,
--                         Cascade Disposal/2012, Houston/5120)
--   • ServiceCodes (3 codes × 2 districts)
--   • RouteEvents (14 events × 2 districts, 92 extra Vancouver events,
--                  11 duplicate-cluster events, 2 Samsara events)
--     → district 2010 (Vancouver) holds exactly 110 route events
--   • EventActions (notes, close, charge, and history entries)
--
-- Idempotent: every INSERT block is guarded with IF NOT EXISTS so the
-- script can be re-run safely.
--
-- Safe on a database that is already populated. Districts are matched on
-- Number, never on a hard-coded Id, so this runs correctly against a
-- database the API's own start-up seeder created -- where the districts
-- carry entirely different identity values -- as well as against an empty
-- one. Route events already present are left alone; this script only adds
-- its own rows, which are all tagged with a '[seed:district-demo]' or
-- 'DUPSEED-' ExternalId.
--
-- Timestamps are computed relative to GETUTCDATE() at execution time,
-- so "minsAgo / daysAgo" values remain realistic on any run date.
--
-- Run order:  01_create_tables.sql  →  02_insert_mock_data.sql
-- ============================================================

SET NOCOUNT ON;
GO

-- ============================================================
-- SECTION 1 — Lookup tables
-- ============================================================

-- Unlike Districts below, the lookup tables DO pin their Ids. The API's
-- own start-up seeder assigns these exact values to these exact names, so
-- pinning them keeps this script and the API in agreement instead of
-- creating a second 'Extra' under a different Id. Id 4 on EventSources is
-- free in an API-seeded database, which is where Samsara lands.

-- ---- EventTypes (IDs 1-5) ---------------------------------
SET IDENTITY_INSERT dbo.EventTypes ON;

IF NOT EXISTS (SELECT 1 FROM dbo.EventTypes WHERE Id = 1)
    INSERT INTO dbo.EventTypes (Id, Name, Active) VALUES (1, N'Extra',             1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventTypes WHERE Id = 2)
    INSERT INTO dbo.EventTypes (Id, Name, Active) VALUES (2, N'Contamination',     1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventTypes WHERE Id = 3)
    INSERT INTO dbo.EventTypes (Id, Name, Active) VALUES (3, N'Overloaded',        1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventTypes WHERE Id = 4)
    INSERT INTO dbo.EventTypes (Id, Name, Active) VALUES (4, N'Blocked Container', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventTypes WHERE Id = 5)
    INSERT INTO dbo.EventTypes (Id, Name, Active) VALUES (5, N'Not Out',           1);

SET IDENTITY_INSERT dbo.EventTypes OFF;
GO

-- ---- EventSources (IDs 1-4) --------------------------------
SET IDENTITY_INSERT dbo.EventSources ON;

IF NOT EXISTS (SELECT 1 FROM dbo.EventSources WHERE Id = 1)
    INSERT INTO dbo.EventSources (Id, Name, Active) VALUES (1, N'WasteVision', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventSources WHERE Id = 2)
    INSERT INTO dbo.EventSources (Id, Name, Active) VALUES (2, N'3rd Eye',     1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventSources WHERE Id = 3)
    INSERT INTO dbo.EventSources (Id, Name, Active) VALUES (3, N'Manual',      1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventSources WHERE Id = 4)
    INSERT INTO dbo.EventSources (Id, Name, Active) VALUES (4, N'Samsara',     1);

SET IDENTITY_INSERT dbo.EventSources OFF;
GO

-- ============================================================
-- SECTION 2 — Districts
-- ============================================================
-- Districts are matched on Number, never on Id. A database seeded by the
-- API's own start-up routine holds twenty districts, and Id 2 there is
-- 2011 OREGON PAPER FIBER -- exactly where this script used to assume
-- Vancouver Minimal. An Id-based guard would find that row, skip its own
-- insert, and quietly hang fourteen events off someone else's district.
-- (2010, 2012 and 5120 happen to land on the same Ids either way; 2010-M
-- is the one that moves. Matching on Number costs nothing and removes the
-- whole class of collision.) Every reference below resolves through it.
--
-- A district that is already present is left exactly as it is: its name,
-- region and hauling system belong to whoever created it.

-- 2010  Vancouver
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Number = N'2010')
    INSERT INTO dbo.Districts (Number, Name, Region, HaulingSystem, Active)
    VALUES (N'2010', N'VANCOUVER', N'Western', 1, 1);

-- 2010-M  Vancouver Minimal — twin district, identical service area, all events shown as Minimal severity
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Number = N'2010-M')
    INSERT INTO dbo.Districts (Number, Name, Region, HaulingSystem, Active)
    VALUES (N'2010-M', N'VANCOUVER MINIMAL', N'Western', 1, 1);

-- 2012  Cascade Disposal
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Number = N'2012')
    INSERT INTO dbo.Districts (Number, Name, Region, HaulingSystem, Active)
    VALUES (N'2012', N'CASCADE DISPOSAL', N'Western', 1, 1);

-- 5120  Houston
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Number = N'5120')
    INSERT INTO dbo.Districts (Number, Name, Region, HaulingSystem, Active)
    VALUES (N'5120', N'HOUSTON', N'Southern', 1, 1);
GO

-- Every district this script writes to must now exist exactly once. The
-- lookups below are scalar subqueries: a missing Number yields NULL and
-- fails 133 inserts one at a time, and a duplicated Number makes the
-- subquery itself an error. Schema does not enforce Number uniqueness, so
-- check it here and stop with one clear message instead.
IF EXISTS (
    SELECT 1 FROM (VALUES (N'2010'), (N'2010-M'), (N'2012'), (N'5120')) AS Wanted(Number)
    WHERE (SELECT COUNT(*) FROM dbo.Districts d WHERE d.Number = Wanted.Number) <> 1
)
BEGIN
    -- Leading semicolon: THROW requires the preceding statement to be terminated.
    ;THROW 50001, 'Seed aborted: each of districts 2010, 2010-M, 2012 and 5120 must exist exactly once in dbo.Districts.', 1;
END
GO

-- ============================================================
-- SECTION 3 — Service codes (districts 2010 and 2010-M)
-- ============================================================

-- District 1 (2010)
IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES ((SELECT Id FROM dbo.Districts WHERE Number = N'2010'), N'EXTRA-COM', N'Extra pickup - Commercial', 70.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'CONTAM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES ((SELECT Id FROM dbo.Districts WHERE Number = N'2010'), N'CONTAM', N'Contamination charge', 90.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'OVERLOAD')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES ((SELECT Id FROM dbo.Districts WHERE Number = N'2010'), N'OVERLOAD', N'Overloaded container charge', 60.0000, 1);

-- District 2 (2010-M)
IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M') AND Code = N'EXTRA-COM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES ((SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), N'EXTRA-COM', N'Extra pickup - Commercial', 70.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M') AND Code = N'CONTAM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES ((SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), N'CONTAM', N'Contamination charge', 90.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M') AND Code = N'OVERLOAD')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES ((SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), N'OVERLOAD', N'Overloaded container charge', 60.0000, 1);
GO

-- ============================================================
-- SECTION 4 — RouteEvents: district 2010 (Vancouver)
--
-- External-id format: [seed:district-demo]-2010-{key}
-- Account format:     2010-{suffix}
-- DateOccurred:      DATEADD(minute, -minsAgo, GETUTCDATE())
-- DateClosed:        DateOccurred + 45 min  (closed/charged only)
-- CustomerSince:     DATEADD(month, -N, GETUTCDATE())
-- ============================================================

-- [c1-wv] Overloaded · WasteVision · open  (minsAgo=132)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c1-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-c1-wv',
        DATEADD(minute, -132, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.6387, -122.6615,
        N'7720 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'CASCADE STATION RETAIL', N'2010-4410092',
        N'CLARK Z2', N'BIN-20115', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-6.jpg',
        N'["/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Severe', DATEADD(month, -103, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [c1-3e] Overloaded · 3rd Eye · open  (minsAgo=129)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c1-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-c1-3e',
        DATEADD(minute, -129, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.63872, -122.66148,
        N'7720 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'CASCADE STATION RETAIL', N'2010-4410092',
        N'CLARK Z2', N'BIN-20115', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-2.jpg"]',
        N'Severe', DATEADD(month, -103, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [c2-wv] Extra · WasteVision · charged  (minsAgo=425)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c2-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-c2-wv',
        DATEADD(minute, -425, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.628, -122.674,
        N'3311 MAIN ST, VANCOUVER, WA',
        N'UPTOWN LOFTS', N'2010-4433001',
        N'CLARK Z1', N'BIN-31200', N'Commercial', N'Linked',
        2.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -16, GETUTCDATE()),
        1, DATEADD(minute, -380, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [c2-3e] Extra · 3rd Eye · closed  (minsAgo=423)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c2-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-c2-3e',
        DATEADD(minute, -423, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.62803, -122.67395,
        N'3311 MAIN ST, VANCOUVER, WA',
        N'UPTOWN LOFTS', N'2010-4433001',
        N'CLARK Z1', N'BIN-31200', N'Commercial', N'Linked',
        2.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-1.jpg"]',
        N'Severe', DATEADD(month, -16, GETUTCDATE()),
        1, DATEADD(minute, -378, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [c3-wv] Contamination · WasteVision · open  (minsAgo=1510, ~25 h ago)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c3-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 1, N'[seed:district-demo]-2010-c3-wv',
        DATEADD(minute, -1510, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.6512, -122.6021,
        N'9812 NE FOURTH PLAIN BLVD, VANCOUVER, WA',
        N'ORCHARDS MARKETPLACE', N'2010-4471180',
        N'CLARK Z3', N'BIN-44518', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Severe', DATEADD(month, -58, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"},{"code":"VA202","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [c3-3e] Contamination · 3rd Eye · open  (minsAgo=1507.5 → 90450 s)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c3-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-c3-3e',
        DATEADD(second, -90450, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.65123, -122.60205,
        N'9812 NE FOURTH PLAIN BLVD, VANCOUVER, WA',
        N'ORCHARDS MARKETPLACE', N'2010-4471180',
        N'CLARK Z3', N'BIN-44518', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Severe', DATEADD(month, -58, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"},{"code":"VA202","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [s1] Blocked Container · WasteVision · open  (minsAgo=220)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 1, N'[seed:district-demo]-2010-s1',
        DATEADD(minute, -220, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.6231, -122.6698,
        N'415 W 8TH ST, VANCOUVER, WA',
        N'COLUMBIA CENTER OFFICES', N'2010-4408831',
        N'CLARK Z1', N'BIN-11842', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -87, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [s2] Not Out · 3rd Eye · closed  (minsAgo=2930, ~2 days ago)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 2, N'[seed:district-demo]-2010-s2',
        DATEADD(minute, -2930, GETUTCDATE()),
        N'2010-133 RSL', N'VR122', 45.6119, -122.5567,
        N'11605 SE MILL PLAIN BLVD, VANCOUVER, WA',
        N'NGUYEN, DANIEL', N'2010-4490277',
        N'CLARK RES Z5', N'BIN-77031', N'Residential', N'Not linked',
        1.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Minimal', DATEADD(month, -29, GETUTCDATE()),
        1, DATEADD(minute, -2885, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VR122","service":"REAR LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [s3] Extra · Manual · open  (minsAgo=95)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s3')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 3, N'[seed:district-demo]-2010-s3',
        DATEADD(minute, -95, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.6448, -122.6402,
        N'5000 E 18TH ST, VANCOUVER, WA',
        N'EVERGREEN SCHOOL DISTRICT #12', N'2010-4402209',
        N'CLARK Z2', N'BIN-55290', N'Commercial', N'Linked',
        3.00, N'/event-photos/truck-cam-8.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-11.jpg"]',
        N'Minimal', DATEADD(month, -148, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [s4] Overloaded · WasteVision · charged  (minsAgo=1740, ~yesterday)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s4')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-s4',
        DATEADD(minute, -1740, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.6055, -122.6811,
        N'100 COLUMBIA WAY, VANCOUVER, WA',
        N'WATERFRONT GRILL', N'2010-4455872',
        N'CLARK Z1', N'BIN-62204', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Severe', DATEADD(month, -41, GETUTCDATE()),
        1, DATEADD(minute, -1695, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA508","service":"FRONT LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [s5] Contamination · Manual · closed  (minsAgo=4310, ~3 days ago)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s5')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 3, N'[seed:district-demo]-2010-s5',
        DATEADD(minute, -4310, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.6591, -122.6939,
        N'2921 NW LOWER RIVER RD, VANCOUVER, WA',
        N'PORT OF VANCOUVER TERMINAL 3', N'2010-4419904',
        N'CLARK Z4', N'BIN-90112', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-4.jpg"]',
        N'Minimal', DATEADD(month, -194, GETUTCDATE()),
        1, DATEADD(minute, -4265, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [s6] Blocked Container · 3rd Eye · open  (minsAgo=305)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s6')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 2, N'[seed:district-demo]-2010-s6',
        DATEADD(minute, -305, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.6172, -122.6533,
        N'700 SE COLUMBIA SHORES BLVD, VANCOUVER, WA',
        N'SHORES MEDICAL PLAZA', N'2010-4462215',
        N'CLARK Z2', N'BIN-38855', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Severe', DATEADD(month, -66, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [s7] Not Out · Manual · open  (minsAgo=2650)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s7')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 3, N'[seed:district-demo]-2010-s7',
        DATEADD(minute, -2650, GETUTCDATE()),
        N'2010-133 RSL', N'VR122', 45.6702, -122.5519,
        N'14508 NE 20TH AVE, VANCOUVER, WA',
        N'RAMIREZ, GLORIA', N'2010-4477310',
        N'CLARK RES Z6', N'BIN-70558', N'Residential', N'Not linked',
        1.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Minimal', DATEADD(month, -8, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR122","service":"REAR LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [s8] Extra · 3rd Eye · charged  (minsAgo=55)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s8')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-s8',
        DATEADD(minute, -55, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.6329, -122.5989,
        N'8802 MILL PLAIN BLVD, VANCOUVER, WA',
        N'MILL PLAIN CROSSING', N'2010-4425567',
        N'CLARK Z3', N'BIN-24471', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Severe', DATEADD(month, -122, GETUTCDATE()),
        1, DATEADD(minute, -10, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );
GO

-- ============================================================
-- SECTION 4B — RouteEvents: district 2010 volume dataset (92 rows)
--
-- Brings Vancouver to 110 route events so the workspace grid
-- exercises pagination, sorting, grouping, filtering and bulk
-- actions against a realistic queue.
--
-- Same conventions as SECTION 4:
--   External-id format: [seed:district-demo]-2010-{key}
--   DateOccurred:       DATEADD(minute, -minsAgo, GETUTCDATE())
--   DateClosed:         DateOccurred + 45 min  (closed/charged only)
--   CustomerSince:      DATEADD(month, -N, GETUTCDATE())
--
-- Keys v01-v80 are single events; d4-d9 are two-vendor duplicate
-- pairs (WasteVision + 3rd Eye, 2-3 min apart, ~3 m apart) that
-- feed duplicate detection and the nearby-overages view.
--
-- Every row carries a value in each column the grid renders
-- (quantity, serial, stop, WO#, address, LOB, tablet notes, bill
-- area, RMO status, customer, customer-since, vehicle, route) plus
-- both a primary photo and a photo array, so neither the grid
-- hover preview nor the detail gallery falls back to a placeholder.
--
-- Mix: 26 Extra / 24 Overloaded / 16 Contamination /
--      12 Blocked Container / 14 Not Out;
--      36 WasteVision / 34 3rd Eye / 14 Manual / 8 Samsara;
--      60 open / 17 closed / 15 charged; 46 Severe / 46 Minimal;
--      44 distinct customers, accounts and addresses.
-- ============================================================

-- [v01] Overloaded · Samsara · open  (minsAgo=7928)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v01')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 4, N'[seed:district-demo]-2010-v01',
        DATEADD(minute, -7928, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.62845, -122.68491,
        N'1305 W 12TH ST, VANCOUVER, WA',
        N'COLUMBIA RIVER BREWING', N'2010-4412006',
        N'CLARK Z1', N'BIN-12034', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'048', N'WO-2010-104061', N'Compactor overfull, could not seat the lid.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-6.jpg"]',
        N'Severe', DATEADD(month, -74, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [v02] Extra · 3rd Eye · charged  (minsAgo=4225)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v02')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v02',
        DATEADD(minute, -4225, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.62481, -122.66050,
        N'612 E RESERVE ST, VANCOUVER, WA',
        N'FORT VANCOUVER PLAZA', N'2010-4413771',
        N'CLARK Z1', N'BIN-13990', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'049', N'WO-2010-104213', N'Driver logged 3 extra bags on the side of the bin.',
        4.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-4.jpg"]',
        N'Minimal', DATEADD(month, -35, GETUTCDATE()),
        1, DATEADD(minute, -4180, GETUTCDATE()), N'Marcus.Lee',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v03] Contamination · 3rd Eye · open  (minsAgo=366)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v03')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-v03',
        DATEADD(minute, -366, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.62683, -122.67607,
        N'610 ESTHER ST, VANCOUVER, WA',
        N'ESTHER SHORT COMMONS', N'2010-4415520',
        N'CLARK Z1', N'BIN-15507', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'091', N'WO-2010-104327', N'Recycle load shows plastic film and food waste.',
        1.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Severe', DATEADD(month, -112, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA508","service":"FRONT LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [v04] Extra · Manual · open  (minsAgo=7442)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v04')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 3, N'[seed:district-demo]-2010-v04',
        DATEADD(minute, -7442, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.62746, -122.67249,
        N'901 C ST, VANCOUVER, WA',
        N'VANCOUVER CENTRAL LIBRARY', N'2010-4416644',
        N'CLARK Z1', N'BIN-16612', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'167', N'WO-2010-104426', N'Two extra toters staged beside the enclosure.',
        3.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-6.jpg"]',
        N'Minimal', DATEADD(month, -61, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v05] Blocked Container · Manual · open  (minsAgo=12007)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v05')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 3, N'[seed:district-demo]-2010-v05',
        DATEADD(minute, -12007, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.63226, -122.65759,
        N'1206 E RESERVE ST, VANCOUVER, WA',
        N'HUDSONS BAY HIGH SCHOOL', N'2010-4417308',
        N'CLARK Z2', N'BIN-17325', N'Commercial', N'Linked',
        N'Container could not be serviced due to obstruction.', N'145', N'WO-2010-104606', N'Snow berm blocking the container pad.',
        1.00, N'/event-photos/truck-cam-5.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -153, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v06] Overloaded · 3rd Eye · charged  (minsAgo=3984)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v06')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-v06',
        DATEADD(minute, -3984, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.60893, -122.57762,
        N'1101 SE TECH CENTER DR, VANCOUVER, WA',
        N'GRAND CENTRAL SHOPPING', N'2010-4418115',
        N'CLARK Z3', N'BIN-18106', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'140', N'WO-2010-104696', N'Container mounded well over the fill line.',
        1.50, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -88, GETUTCDATE()),
        1, DATEADD(minute, -3939, GETUTCDATE()), N'Marcus.Lee',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [v07] Blocked Container · 3rd Eye · closed  (minsAgo=8293)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v07')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 2, N'[seed:district-demo]-2010-v07',
        DATEADD(minute, -8293, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.63366, -122.72671,
        N'3103 NW LOWER RIVER RD, VANCOUVER, WA',
        N'PORT OF VANCOUVER TERMINAL 5', N'2010-4419912',
        N'CLARK Z4', N'BIN-19928', N'Industrial', N'Linked',
        N'Access blocked, stop skipped on this pass.', N'063', N'WO-2010-104823', N'Snow berm blocking the container pad.',
        1.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Minimal', DATEADD(month, -201, GETUTCDATE()),
        1, DATEADD(minute, -8248, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v08] Blocked Container · Samsara · closed  (minsAgo=3291)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v08')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 4, N'[seed:district-demo]-2010-v08',
        DATEADD(minute, -3291, GETUTCDATE()),
        N'2010-145 FEL', N'VA406', 45.70749, -122.66117,
        N'2211 NE 139TH ST, VANCOUVER, WA',
        N'SALMON CREEK MEDICAL CENTER', N'2010-4420483',
        N'CLARK Z6', N'BIN-20488', N'Commercial', N'Linked',
        N'Access blocked, stop skipped on this pass.', N'136', N'WO-2010-105018', N'Vehicle parked in front of the enclosure.',
        1.00, N'/event-photos/truck-cam-5.jpg',
        N'["/event-photos/truck-cam-13.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -44, GETUTCDATE()),
        1, DATEADD(minute, -3246, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"},{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v09] Overloaded · WasteVision · open  (minsAgo=8904)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v09')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v09',
        DATEADD(minute, -8904, GETUTCDATE()),
        N'2010-152 REL', N'VR215', 45.69825, -122.71023,
        N'2508 NW 119TH ST, VANCOUVER, WA',
        N'FELIDA CORNER MARKET', N'2010-4421771',
        N'CLARK Z4', N'BIN-21744', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'004', N'WO-2010-105180', N'Load spilling from the top of the bin.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-13.jpg","/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -19, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR215","service":"REAR LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v10] Overloaded · Manual · open  (minsAgo=3090)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v10')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 3, N'[seed:district-demo]-2010-v10',
        DATEADD(minute, -3090, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.67234, -122.62497,
        N'3405 NE 78TH ST, VANCOUVER, WA',
        N'BURNT BRIDGE CREEK APARTMENTS', N'2010-4422640',
        N'CLARK Z2', N'BIN-22619', N'Commercial', N'Linked',
        N'Weight and fill line both exceeded.', N'141', N'WO-2010-105266', N'Container mounded well over the fill line.',
        1.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Minimal', DATEADD(month, -57, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"},{"code":"VA202","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v11] Overloaded · Manual · charged  (minsAgo=14243)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v11')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 3, N'[seed:district-demo]-2010-v11',
        DATEADD(minute, -14243, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.66148, -122.63813,
        N'4207 NE ST JOHNS RD, VANCOUVER, WA',
        N'MINNEHAHA HARDWARE', N'2010-4423915',
        N'CLARK Z2', N'BIN-23904', N'Commercial', N'Linked',
        N'Weight and fill line both exceeded.', N'027', N'WO-2010-105387', N'Compactor overfull, could not seat the lid.',
        1.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Severe', DATEADD(month, -31, GETUTCDATE()),
        1, DATEADD(minute, -14198, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v12] Extra · Samsara · charged  (minsAgo=3862)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v12')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 4, N'[seed:district-demo]-2010-v12',
        DATEADD(minute, -3862, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.61680, -122.55067,
        N'12100 SE 5TH ST, VANCOUVER, WA',
        N'CASCADE PARK DENTAL GROUP', N'2010-4424318',
        N'CLARK Z3', N'BIN-24371', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'165', N'WO-2010-105552', N'Two extra toters staged beside the enclosure.',
        4.00, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -12, GETUTCDATE()),
        1, DATEADD(minute, -3817, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v13] Contamination · WasteVision · charged  (minsAgo=6647)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v13')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 1, N'[seed:district-demo]-2010-v13',
        DATEADD(minute, -6647, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.67101, -122.55451,
        N'11002 NE 117TH AVE, VANCOUVER, WA',
        N'ORCHARDS FEED AND SUPPLY', N'2010-4426082',
        N'CLARK Z3', N'BIN-26018', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'142', N'WO-2010-105657', N'Yard debris cart has plastic bags mixed in.',
        1.00, N'/event-photos/truck-cam-5.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Minimal', DATEADD(month, -96, GETUTCDATE()),
        1, DATEADD(minute, -6602, GETUTCDATE()), N'Sofia.Alvarez',
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v14] Contamination · 3rd Eye · open  (minsAgo=1022)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v14')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-v14',
        DATEADD(minute, -1022, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.63000, -122.67082,
        N'900 WASHINGTON ST, VANCOUVER, WA',
        N'RIVERVIEW COMMUNITY BANK', N'2010-4427260',
        N'CLARK Z1', N'BIN-27255', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'004', N'WO-2010-105781', N'Glass and styrofoam found in commingle.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Severe', DATEADD(month, -134, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v15] Overloaded · 3rd Eye · open  (minsAgo=3429)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v15')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-v15',
        DATEADD(minute, -3429, GETUTCDATE()),
        N'2010-145 FEL', N'VA406', 45.70783, -122.64919,
        N'2525 NE 139TH ST, VANCOUVER, WA',
        N'THE VANCOUVER CLINIC SALMON CREEK', N'2010-4428443',
        N'CLARK Z6', N'BIN-28401', N'Commercial', N'Linked',
        N'Weight and fill line both exceeded.', N'050', N'WO-2010-105943', N'Compactor overfull, could not seat the lid.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-8.jpg"]',
        N'Minimal', DATEADD(month, -68, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [v16] Extra · WasteVision · charged  (minsAgo=273)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v16')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v16',
        DATEADD(minute, -273, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.62025, -122.57342,
        N'9500 SE MILL PLAIN BLVD, VANCOUVER, WA',
        N'EAST MILL PLAIN SELF STORAGE', N'2010-4429177',
        N'CLARK Z3', N'BIN-29140', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'016', N'WO-2010-106115', N'Extra cardboard bales left at the dock.',
        2.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -23, GETUTCDATE()),
        1, DATEADD(minute, -228, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v17] Contamination · 3rd Eye · charged  (minsAgo=925)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v17')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-v17',
        DATEADD(minute, -925, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.65926, -122.58900,
        N'8800 NE 62ND AVE, VANCOUVER, WA',
        N'SIFTON ELEMENTARY SCHOOL', N'2010-4430512',
        N'CLARK Z3', N'BIN-30588', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'026', N'WO-2010-106267', N'Recycle load shows plastic film and food waste.',
        1.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Severe', DATEADD(month, -176, GETUTCDATE()),
        1, DATEADD(minute, -880, GETUTCDATE()), N'Sofia.Alvarez',
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v18] Not Out · WasteVision · open  (minsAgo=821)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v18')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 1, N'[seed:district-demo]-2010-v18',
        DATEADD(minute, -821, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.66689, -122.59679,
        N'9800 NE 76TH ST, VANCOUVER, WA',
        N'LEWIS AND CLARK TRUCK STOP', N'2010-4431806',
        N'CLARK Z3', N'BIN-31877', N'Industrial', N'Linked',
        N'No service performed, nothing set out.', N'105', N'WO-2010-106361', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-8.jpg"]',
        N'Minimal', DATEADD(month, -49, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"},{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v19] Overloaded · 3rd Eye · open  (minsAgo=2531)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v19')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-v19',
        DATEADD(minute, -2531, GETUTCDATE()),
        N'2010-152 REL', N'VR215', 45.68010, -122.66135,
        N'7317 NE HIGHWAY 99, VANCOUVER, WA',
        N'HAZEL DELL LANES', N'2010-4432094',
        N'CLARK Z4', N'BIN-32013', N'Commercial', N'Linked',
        N'Weight and fill line both exceeded.', N'085', N'WO-2010-106547', N'Compactor overfull, could not seat the lid.',
        1.50, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-7.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Minimal', DATEADD(month, -82, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR215","service":"REAR LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v20] Extra · 3rd Eye · open  (minsAgo=5718)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v20')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v20',
        DATEADD(minute, -5718, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.65873, -122.70217,
        N'5401 NW FRUIT VALLEY RD, VANCOUVER, WA',
        N'NORTHWEST PRECISION MACHINE', N'2010-4434128',
        N'CLARK Z4', N'BIN-34117', N'Industrial', N'Linked',
        N'Extra volume beyond contracted service level.', N'057', N'WO-2010-106620', N'Overflow cart set out at the curb, not on service.',
        3.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -108, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

GO


-- [v21] Extra · WasteVision · open  (minsAgo=157)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v21')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v21',
        DATEADD(minute, -157, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.61874, -122.53929,
        N'13215 SE MILL PLAIN BLVD, VANCOUVER, WA',
        N'PACIFIC PARK VETERINARY', N'2010-4435761',
        N'CLARK Z3', N'BIN-35702', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'148', N'WO-2010-106751', N'Extra cardboard bales left at the dock.',
        3.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-11.jpg"]',
        N'Severe', DATEADD(month, -27, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v22] Overloaded · Samsara · charged  (minsAgo=16899)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v22')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 4, N'[seed:district-demo]-2010-v22',
        DATEADD(minute, -16899, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.61032, -122.57511,
        N'1498 SE TECH CENTER PL, VANCOUVER, WA',
        N'COLUMBIA TECH CENTER OFFICES', N'2010-4436344',
        N'CLARK Z3', N'BIN-36320', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'096', N'WO-2010-106940', N'Load spilling from the top of the bin.',
        1.00, N'/event-photos/truck-cam-8.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-6.jpg"]',
        N'Severe', DATEADD(month, -53, GETUTCDATE()),
        1, DATEADD(minute, -16854, GETUTCDATE()), N'Sofia.Alvarez',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [v23] Not Out · Samsara · open  (minsAgo=645)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v23')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 4, N'[seed:district-demo]-2010-v23',
        DATEADD(minute, -645, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.63656, -122.65580,
        N'1600 E 20TH ST, VANCOUVER, WA',
        N'ROSE VILLAGE COMMUNITY CENTER', N'2010-4437509',
        N'CLARK Z2', N'BIN-37551', N'Commercial', N'Linked',
        N'No service performed, nothing set out.', N'037', N'WO-2010-107014', N'Service point empty on arrival.',
        1.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -119, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v24] Contamination · WasteVision · charged  (minsAgo=1174)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v24')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 1, N'[seed:district-demo]-2010-v24',
        DATEADD(minute, -1174, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.66085, -122.62992,
        N'4211 NE MINNEHAHA ST, VANCOUVER, WA',
        N'BAGLEY DOWNS DINER', N'2010-4438870',
        N'CLARK Z2', N'BIN-38812', N'Commercial', N'Linked',
        N'Load rejected for contamination at the stop.', N'026', N'WO-2010-107170', N'Yard debris cart has plastic bags mixed in.',
        1.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-2.jpg"]',
        N'Minimal', DATEADD(month, -15, GETUTCDATE()),
        1, DATEADD(minute, -1129, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v25] Blocked Container · Manual · open  (minsAgo=342)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v25')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 3, N'[seed:district-demo]-2010-v25',
        DATEADD(minute, -342, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.65503, -122.70158,
        N'3600 NW ST JOHNS RD, VANCOUVER, WA',
        N'FRUIT VALLEY COLD STORAGE', N'2010-4439233',
        N'CLARK Z4', N'BIN-39270', N'Industrial', N'Linked',
        N'Access blocked, stop skipped on this pass.', N'071', N'WO-2010-107340', N'Gate locked, no access code on file.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-13.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -143, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v26] Overloaded · WasteVision · open  (minsAgo=15010)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v26')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v26',
        DATEADD(minute, -15010, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.62829, -122.67635,
        N'1005 ESTHER ST, VANCOUVER, WA',
        N'ESTHER STREET DENTAL', N'2010-4440168',
        N'CLARK Z1', N'BIN-40115', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'067', N'WO-2010-107431', N'Load spilling from the top of the bin.',
        1.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-7.jpg","/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-4.jpg"]',
        N'Minimal', DATEADD(month, -9, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v27] Contamination · 3rd Eye · closed  (minsAgo=6101)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v27')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-v27',
        DATEADD(minute, -6101, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.64100, -122.60025,
        N'8700 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'VANCOUVER MALL FOOD COURT', N'2010-4441780',
        N'CLARK Z2', N'BIN-41722', N'Commercial', N'Linked',
        N'Load rejected for contamination at the stop.', N'080', N'WO-2010-107645', N'Yard debris cart has plastic bags mixed in.',
        1.00, N'/event-photos/truck-cam-6.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -167, GETUTCDATE()),
        1, DATEADD(minute, -6056, GETUTCDATE()), N'Marcus.Lee',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [v28] Overloaded · 3rd Eye · closed  (minsAgo=451)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v28')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-v28',
        DATEADD(minute, -451, GETUTCDATE()),
        N'2010-152 REL', N'VR418', 45.59768, -122.57846,
        N'9105 SE EVERGREEN HWY, VANCOUVER, WA',
        N'EVERGREEN HIGHWAY GARDENS', N'2010-4442391',
        N'CLARK Z3', N'BIN-42350', N'Commercial', N'Linked',
        N'Weight and fill line both exceeded.', N'075', N'WO-2010-107784', N'Compactor overfull, could not seat the lid.',
        1.50, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Minimal', DATEADD(month, -38, GETUTCDATE()),
        1, DATEADD(minute, -406, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v29] Extra · WasteVision · closed  (minsAgo=743)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v29')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v29',
        DATEADD(minute, -743, GETUTCDATE()),
        N'2010-152 REL', N'VR215', 45.67103, -122.68260,
        N'1201 NW 78TH ST, VANCOUVER, WA',
        N'WEST HAZEL DELL LAUNDROMAT', N'2010-4443604',
        N'CLARK Z4', N'BIN-43668', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'115', N'WO-2010-107901', N'Extra cardboard bales left at the dock.',
        2.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-4.jpg"]',
        N'Minimal', DATEADD(month, -21, GETUTCDATE()),
        1, DATEADD(minute, -698, GETUTCDATE()), N'Marcus.Lee',
        N'[{"code":"VR215","service":"REAR LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v30] Extra · Samsara · open  (minsAgo=79)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v30')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 4, N'[seed:district-demo]-2010-v30',
        DATEADD(minute, -79, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.75413, -122.66627,
        N'17402 NE DELFEL RD, RIDGEFIELD, WA',
        N'CLARK COUNTY FAIRGROUNDS', N'2010-4445019',
        N'CLARK Z6', N'BIN-45072', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'093', N'WO-2010-108018', N'Two extra toters staged beside the enclosure.',
        2.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Severe', DATEADD(month, -188, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v31] Contamination · 3rd Eye · open  (minsAgo=2132)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v31')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-v31',
        DATEADD(minute, -2132, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.63985, -122.67151,
        N'2506 MAIN ST, VANCOUVER, WA',
        N'ARNADA HOUSE APARTMENTS', N'2010-4446238',
        N'CLARK Z1', N'BIN-46200', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'069', N'WO-2010-108120', N'Glass and styrofoam found in commingle.',
        1.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Severe', DATEADD(month, -33, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [v32] Extra · WasteVision · open  (minsAgo=7752)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v32')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v32',
        DATEADD(minute, -7752, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.63715, -122.69187,
        N'2801 W 24TH ST, VANCOUVER, WA',
        N'LINCOLN NEIGHBORHOOD GROCERY', N'2010-4447512',
        N'CLARK Z1', N'BIN-47551', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'039', N'WO-2010-108329', N'Driver logged 3 extra bags on the side of the bin.',
        4.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Severe', DATEADD(month, -46, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v33] Extra · WasteVision · open  (minsAgo=2682)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v33')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v33',
        DATEADD(minute, -2682, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.63503, -122.67258,
        N'1900 MAIN ST, VANCOUVER, WA',
        N'HOUGH TIRE AND AUTO', N'2010-4448903',
        N'CLARK Z1', N'BIN-48940', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'169', N'WO-2010-108387', N'Overflow cart set out at the curb, not on service.',
        2.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -72, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v34] Overloaded · WasteVision · open  (minsAgo=680)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v34')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v34',
        DATEADD(minute, -680, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.66568, -122.54834,
        N'12009 NE 99TH ST, VANCOUVER, WA',
        N'WALNUT GROVE BUSINESS PARK', N'2010-4450226',
        N'CLARK Z3', N'BIN-50218', N'Commercial', N'Linked',
        N'Weight and fill line both exceeded.', N'132', N'WO-2010-108603', N'Lid propped open, load above the rails.',
        1.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Severe', DATEADD(month, -64, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v35] Not Out · Samsara · open  (minsAgo=558)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v35')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 4, N'[seed:district-demo]-2010-v35',
        DATEADD(minute, -558, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.60265, -122.50319,
        N'3510 SE 164TH AVE, VANCOUVER, WA',
        N'FISHERS LANDING TRANSIT CENTER', N'2010-4452007',
        N'CLARK Z3', N'BIN-52033', N'Commercial', N'Linked',
        N'No service performed, nothing set out.', N'126', N'WO-2010-108687', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-11.jpg"]',
        N'Minimal', DATEADD(month, -91, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v36] Extra · WasteVision · open  (minsAgo=4736)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v36')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v36',
        DATEADD(minute, -4736, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.61004, -122.56328,
        N'1301 SE ELLSWORTH RD, VANCOUVER, WA',
        N'ELLSWORTH SPRINGS TOWNHOMES', N'2010-4453118',
        N'CLARK Z3', N'BIN-53177', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'023', N'WO-2010-108835', N'Two extra toters staged beside the enclosure.',
        1.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-7.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Minimal', DATEADD(month, -26, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [v37] Extra · 3rd Eye · charged  (minsAgo=3702)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v37')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v37',
        DATEADD(minute, -3702, GETUTCDATE()),
        N'2010-133 RSL', N'VR122', 45.66600, -122.61871,
        N'7304 NE 47TH AVE, VANCOUVER, WA',
        N'OKONKWO, ADAEZE', N'2010-4460114',
        N'CLARK RES Z5', N'BIN-60148', N'Residential', N'Not linked',
        N'Extra volume beyond contracted service level.', N'105', N'WO-2010-108969', N'Driver logged 3 extra bags on the side of the bin.',
        2.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -11, GETUTCDATE()),
        1, DATEADD(minute, -3657, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VR122","service":"REAR LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [v38] Not Out · WasteVision · closed  (minsAgo=5190)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v38')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 1, N'[seed:district-demo]-2010-v38',
        DATEADD(minute, -5190, GETUTCDATE()),
        N'2010-133 RSL', N'VR122', 45.66635, -122.63995,
        N'2914 NE 68TH ST, VANCOUVER, WA',
        N'MCALLISTER, BRENDA', N'2010-4461330',
        N'CLARK RES Z5', N'BIN-61390', N'Residential', N'Not linked',
        N'No service performed, nothing set out.', N'066', N'WO-2010-109128', N'Cart set out after the truck cleared the stop.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -48, GETUTCDATE()),
        1, DATEADD(minute, -5145, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"VR122","service":"REAR LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [v39] Not Out · 3rd Eye · open  (minsAgo=966)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v39')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 2, N'[seed:district-demo]-2010-v39',
        DATEADD(minute, -966, GETUTCDATE()),
        N'2010-158 RSL', N'VR418', 45.60942, -122.51163,
        N'15414 SE 20TH ST, VANCOUVER, WA',
        N'SORENSEN, PAUL', N'2010-4462078',
        N'CLARK RES Z6', N'BIN-62011', N'Residential', N'Not linked',
        N'Container was not out for scheduled service.', N'124', N'WO-2010-109214', N'Cart set out after the truck cleared the stop.',
        1.00, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-3.jpg"]',
        N'Severe', DATEADD(month, -6, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v40] Blocked Container · Manual · closed  (minsAgo=9120)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v40')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 3, N'[seed:district-demo]-2010-v40',
        DATEADD(minute, -9120, GETUTCDATE()),
        N'2010-133 RSL', N'VR122', 45.68455, -122.64230,
        N'10112 NE 22ND AVE, VANCOUVER, WA',
        N'TRAN, MICHELLE', N'2010-4463491',
        N'CLARK RES Z5', N'BIN-63455', N'Residential', N'Not linked',
        N'Access blocked, stop skipped on this pass.', N'153', N'WO-2010-109387', N'Vehicle parked in front of the enclosure.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Minimal', DATEADD(month, -30, GETUTCDATE()),
        1, DATEADD(minute, -9075, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"VR122","service":"REAR LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

GO


-- [v41] Extra · WasteVision · open  (minsAgo=8612)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v41')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v41',
        DATEADD(minute, -8612, GETUTCDATE()),
        N'2010-158 RSL', N'VR418', 45.64589, -122.56357,
        N'5719 NE 105TH AVE, VANCOUVER, WA',
        N'ABERNATHY, RUTH', N'2010-4464820',
        N'CLARK RES Z6', N'BIN-64877', N'Residential', N'Not linked',
        N'Additional set-out recorded by the driver.', N'043', N'WO-2010-109511', N'Extra cardboard bales left at the dock.',
        1.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-2.jpg"]',
        N'Severe', DATEADD(month, -96, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v42] Not Out · Manual · closed  (minsAgo=844)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v42')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 3, N'[seed:district-demo]-2010-v42',
        DATEADD(minute, -844, GETUTCDATE()),
        N'2010-158 RSL', N'VR418', 45.63397, -122.53048,
        N'13519 NE 28TH ST, VANCOUVER, WA',
        N'DELACRUZ, MARTIN', N'2010-4465209',
        N'CLARK RES Z6', N'BIN-65240', N'Residential', N'Not linked',
        N'No service performed, nothing set out.', N'053', N'WO-2010-109647', N'Cart set out after the truck cleared the stop.',
        1.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -17, GETUTCDATE()),
        1, DATEADD(minute, -799, GETUTCDATE()), N'Marcus.Lee',
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v43] Blocked Container · 3rd Eye · closed  (minsAgo=4470)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v43')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 2, N'[seed:district-demo]-2010-v43',
        DATEADD(minute, -4470, GETUTCDATE()),
        N'2010-133 RSL', N'VR215', 45.67335, -122.70351,
        N'4508 NW BERNIE DR, VANCOUVER, WA',
        N'KOWALSKI, JANET', N'2010-4466711',
        N'CLARK RES Z5', N'BIN-66703', N'Residential', N'Not linked',
        N'Access blocked, stop skipped on this pass.', N'001', N'WO-2010-109830', N'Vehicle parked in front of the enclosure.',
        1.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-6.jpg"]',
        N'Severe', DATEADD(month, -54, GETUTCDATE()),
        1, DATEADD(minute, -4425, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VR215","service":"REAR LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v44] Extra · WasteVision · closed  (minsAgo=123)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v44')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v44',
        DATEADD(minute, -123, GETUTCDATE()),
        N'2010-158 RSL', N'VR418', 45.66260, -122.52077,
        N'8210 NE 152ND AVE, VANCOUVER, WA',
        N'OYELARAN, TOBI', N'2010-4467933',
        N'CLARK RES Z6', N'BIN-67991', N'Residential', N'Not linked',
        N'Extra volume beyond contracted service level.', N'100', N'WO-2010-109908', N'Driver logged 3 extra bags on the side of the bin.',
        1.00, N'/event-photos/truck-cam-6.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-2.jpg"]',
        N'Severe', DATEADD(month, -8, GETUTCDATE()),
        1, DATEADD(minute, -78, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v45] Not Out · 3rd Eye · open  (minsAgo=1089)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v45')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 2, N'[seed:district-demo]-2010-v45',
        DATEADD(minute, -1089, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.62883, -122.68568,
        N'1305 W 12TH ST, VANCOUVER, WA',
        N'COLUMBIA RIVER BREWING', N'2010-4412006',
        N'CLARK Z1', N'BIN-12034', N'Commercial', N'Linked',
        N'Container was not out for scheduled service.', N'149', N'WO-2010-110036', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-7.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -74, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [v46] Contamination · 3rd Eye · closed  (minsAgo=5417)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v46')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-v46',
        DATEADD(minute, -5417, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.62520, -122.66109,
        N'612 E RESERVE ST, VANCOUVER, WA',
        N'FORT VANCOUVER PLAZA', N'2010-4413771',
        N'CLARK Z1', N'BIN-13990', N'Commercial', N'Linked',
        N'Load rejected for contamination at the stop.', N'126', N'WO-2010-110249', N'Yard debris cart has plastic bags mixed in.',
        1.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-13.jpg","/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -35, GETUTCDATE()),
        1, DATEADD(minute, -5372, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v47] Contamination · Manual · open  (minsAgo=7093)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v47')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 3, N'[seed:district-demo]-2010-v47',
        DATEADD(minute, -7093, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.62639, -122.67491,
        N'610 ESTHER ST, VANCOUVER, WA',
        N'ESTHER SHORT COMMONS', N'2010-4415520',
        N'CLARK Z1', N'BIN-15507', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'081', N'WO-2010-110312', N'Cardboard bin contains wet garbage.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-6.jpg"]',
        N'Severe', DATEADD(month, -112, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA508","service":"FRONT LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [v48] Extra · 3rd Eye · closed  (minsAgo=2243)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v48')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v48',
        DATEADD(minute, -2243, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.62714, -122.67153,
        N'901 C ST, VANCOUVER, WA',
        N'VANCOUVER CENTRAL LIBRARY', N'2010-4416644',
        N'CLARK Z1', N'BIN-16612', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'159', N'WO-2010-110455', N'Two extra toters staged beside the enclosure.',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Severe', DATEADD(month, -61, GETUTCDATE()),
        1, DATEADD(minute, -2198, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v49] Contamination · WasteVision · closed  (minsAgo=9761)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v49')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 1, N'[seed:district-demo]-2010-v49',
        DATEADD(minute, -9761, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.63185, -122.65850,
        N'1206 E RESERVE ST, VANCOUVER, WA',
        N'HUDSONS BAY HIGH SCHOOL', N'2010-4417308',
        N'CLARK Z2', N'BIN-17325', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'122', N'WO-2010-110587', N'Glass and styrofoam found in commingle.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-3.jpg"]',
        N'Severe', DATEADD(month, -153, GETUTCDATE()),
        1, DATEADD(minute, -9716, GETUTCDATE()), N'Marcus.Lee',
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v50] Extra · 3rd Eye · open  (minsAgo=1427)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v50')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v50',
        DATEADD(minute, -1427, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.60808, -122.57756,
        N'1101 SE TECH CENTER DR, VANCOUVER, WA',
        N'GRAND CENTRAL SHOPPING', N'2010-4418115',
        N'CLARK Z3', N'BIN-18106', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'163', N'WO-2010-110737', N'Extra cardboard bales left at the dock.',
        2.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-2.jpg"]',
        N'Minimal', DATEADD(month, -88, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [v51] Overloaded · 3rd Eye · closed  (minsAgo=4149)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v51')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-v51',
        DATEADD(minute, -4149, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.63461, -122.72611,
        N'3103 NW LOWER RIVER RD, VANCOUVER, WA',
        N'PORT OF VANCOUVER TERMINAL 5', N'2010-4419912',
        N'CLARK Z4', N'BIN-19928', N'Industrial', N'Linked',
        N'Weight and fill line both exceeded.', N'046', N'WO-2010-110864', N'Container mounded well over the fill line.',
        1.50, N'/event-photos/truck-cam-6.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -201, GETUTCDATE()),
        1, DATEADD(minute, -4104, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v52] Extra · 3rd Eye · charged  (minsAgo=242)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v52')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v52',
        DATEADD(minute, -242, GETUTCDATE()),
        N'2010-145 FEL', N'VA406', 45.70749, -122.66110,
        N'2211 NE 139TH ST, VANCOUVER, WA',
        N'SALMON CREEK MEDICAL CENTER', N'2010-4420483',
        N'CLARK Z6', N'BIN-20488', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'167', N'WO-2010-111051', N'Driver logged 3 extra bags on the side of the bin.',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Severe', DATEADD(month, -44, GETUTCDATE()),
        1, DATEADD(minute, -197, GETUTCDATE()), N'Dana.Whitfield',
        N'[{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"},{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v53] Contamination · Manual · closed  (minsAgo=1589)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v53')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 3, N'[seed:district-demo]-2010-v53',
        DATEADD(minute, -1589, GETUTCDATE()),
        N'2010-152 REL', N'VR215', 45.69761, -122.70950,
        N'2508 NW 119TH ST, VANCOUVER, WA',
        N'FELIDA CORNER MARKET', N'2010-4421771',
        N'CLARK Z4', N'BIN-21744', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'074', N'WO-2010-111131', N'Cardboard bin contains wet garbage.',
        1.00, N'/event-photos/truck-cam-8.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-11.jpg"]',
        N'Severe', DATEADD(month, -19, GETUTCDATE()),
        1, DATEADD(minute, -1544, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"VR215","service":"REAR LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v54] Extra · 3rd Eye · open  (minsAgo=1747)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v54')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v54',
        DATEADD(minute, -1747, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.67156, -122.62469,
        N'3405 NE 78TH ST, VANCOUVER, WA',
        N'BURNT BRIDGE CREEK APARTMENTS', N'2010-4422640',
        N'CLARK Z2', N'BIN-22619', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'018', N'WO-2010-111314', N'Two extra toters staged beside the enclosure.',
        3.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-6.jpg"]',
        N'Severe', DATEADD(month, -57, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"},{"code":"VA202","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v55] Overloaded · Manual · open  (minsAgo=3537)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v55')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 3, N'[seed:district-demo]-2010-v55',
        DATEADD(minute, -3537, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.66172, -122.63936,
        N'4207 NE ST JOHNS RD, VANCOUVER, WA',
        N'MINNEHAHA HARDWARE', N'2010-4423915',
        N'CLARK Z2', N'BIN-23904', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'055', N'WO-2010-111406', N'Load spilling from the top of the bin.',
        1.50, N'/event-photos/truck-cam-5.jpg',
        N'["/event-photos/truck-cam-13.jpg","/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -31, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v56] Extra · WasteVision · open  (minsAgo=9526)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v56')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v56',
        DATEADD(minute, -9526, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.61692, -122.55055,
        N'12100 SE 5TH ST, VANCOUVER, WA',
        N'CASCADE PARK DENTAL GROUP', N'2010-4424318',
        N'CLARK Z3', N'BIN-24371', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'127', N'WO-2010-111606', N'Extra cardboard bales left at the dock.',
        2.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -12, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v57] Overloaded · WasteVision · charged  (minsAgo=2445)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v57')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v57',
        DATEADD(minute, -2445, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.67053, -122.55436,
        N'11002 NE 117TH AVE, VANCOUVER, WA',
        N'ORCHARDS FEED AND SUPPLY', N'2010-4426082',
        N'CLARK Z3', N'BIN-26018', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'037', N'WO-2010-111717', N'Compactor overfull, could not seat the lid.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Minimal', DATEADD(month, -96, GETUTCDATE()),
        1, DATEADD(minute, -2400, GETUTCDATE()), N'Sofia.Alvarez',
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v58] Extra · 3rd Eye · open  (minsAgo=11414)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v58')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-v58',
        DATEADD(minute, -11414, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.63000, -122.67068,
        N'900 WASHINGTON ST, VANCOUVER, WA',
        N'RIVERVIEW COMMUNITY BANK', N'2010-4427260',
        N'CLARK Z1', N'BIN-27255', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'127', N'WO-2010-111868', N'Overflow cart set out at the curb, not on service.',
        1.00, N'/event-photos/truck-cam-8.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Severe', DATEADD(month, -134, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v59] Overloaded · Manual · open  (minsAgo=13272)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v59')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 3, N'[seed:district-demo]-2010-v59',
        DATEADD(minute, -13272, GETUTCDATE()),
        N'2010-145 FEL', N'VA406', 45.70885, -122.64815,
        N'2525 NE 139TH ST, VANCOUVER, WA',
        N'THE VANCOUVER CLINIC SALMON CREEK', N'2010-4428443',
        N'CLARK Z6', N'BIN-28401', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'012', N'WO-2010-111982', N'Compactor overfull, could not seat the lid.',
        1.00, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Minimal', DATEADD(month, -68, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [v60] Overloaded · WasteVision · open  (minsAgo=6480)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v60')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v60',
        DATEADD(minute, -6480, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.61973, -122.57334,
        N'9500 SE MILL PLAIN BLVD, VANCOUVER, WA',
        N'EAST MILL PLAIN SELF STORAGE', N'2010-4429177',
        N'CLARK Z3', N'BIN-29140', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'062', N'WO-2010-112120', N'Lid propped open, load above the rails.',
        1.50, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Severe', DATEADD(month, -23, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

GO


-- [v61] Contamination · 3rd Eye · open  (minsAgo=323)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v61')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-v61',
        DATEADD(minute, -323, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.66043, -122.58798,
        N'8800 NE 62ND AVE, VANCOUVER, WA',
        N'SIFTON ELEMENTARY SCHOOL', N'2010-4430512',
        N'CLARK Z3', N'BIN-30588', N'Commercial', N'Linked',
        N'Load rejected for contamination at the stop.', N'057', N'WO-2010-112230', N'Cardboard bin contains wet garbage.',
        1.00, N'/event-photos/truck-cam-5.jpg',
        N'["/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-8.jpg"]',
        N'Severe', DATEADD(month, -176, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v62] Blocked Container · 3rd Eye · open  (minsAgo=1215)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v62')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 2, N'[seed:district-demo]-2010-v62',
        DATEADD(minute, -1215, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.66701, -122.59732,
        N'9800 NE 76TH ST, VANCOUVER, WA',
        N'LEWIS AND CLARK TRUCK STOP', N'2010-4431806',
        N'CLARK Z3', N'BIN-31877', N'Industrial', N'Linked',
        N'Access blocked, stop skipped on this pass.', N'027', N'WO-2010-112407', N'Gate locked, no access code on file.',
        1.00, N'/event-photos/truck-cam-8.jpg',
        N'["/event-photos/truck-cam-13.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Severe', DATEADD(month, -49, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"},{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v63] Overloaded · WasteVision · open  (minsAgo=181)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v63')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v63',
        DATEADD(minute, -181, GETUTCDATE()),
        N'2010-152 REL', N'VR215', 45.67944, -122.66246,
        N'7317 NE HIGHWAY 99, VANCOUVER, WA',
        N'HAZEL DELL LANES', N'2010-4432094',
        N'CLARK Z4', N'BIN-32013', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'062', N'WO-2010-112526', N'Compactor overfull, could not seat the lid.',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Severe', DATEADD(month, -82, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR215","service":"REAR LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v64] Blocked Container · Manual · open  (minsAgo=25)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v64')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 3, N'[seed:district-demo]-2010-v64',
        DATEADD(minute, -25, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.65897, -122.70314,
        N'5401 NW FRUIT VALLEY RD, VANCOUVER, WA',
        N'NORTHWEST PRECISION MACHINE', N'2010-4434128',
        N'CLARK Z4', N'BIN-34117', N'Industrial', N'Linked',
        N'Container could not be serviced due to obstruction.', N'018', N'WO-2010-112680', N'Snow berm blocking the container pad.',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -108, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v65] Blocked Container · 3rd Eye · open  (minsAgo=101)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v65')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 2, N'[seed:district-demo]-2010-v65',
        DATEADD(minute, -101, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.61808, -122.53922,
        N'13215 SE MILL PLAIN BLVD, VANCOUVER, WA',
        N'PACIFIC PARK VETERINARY', N'2010-4435761',
        N'CLARK Z3', N'BIN-35702', N'Commercial', N'Linked',
        N'Container could not be serviced due to obstruction.', N'042', N'WO-2010-112806', N'Vehicle parked in front of the enclosure.',
        1.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-11.jpg"]',
        N'Severe', DATEADD(month, -27, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v66] Blocked Container · WasteVision · open  (minsAgo=1281)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v66')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 1, N'[seed:district-demo]-2010-v66',
        DATEADD(minute, -1281, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.61017, -122.57391,
        N'1498 SE TECH CENTER PL, VANCOUVER, WA',
        N'COLUMBIA TECH CENTER OFFICES', N'2010-4436344',
        N'CLARK Z3', N'BIN-36320', N'Commercial', N'Linked',
        N'Access blocked, stop skipped on this pass.', N'083', N'WO-2010-112945', N'Gate locked, no access code on file.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-3.jpg"]',
        N'Minimal', DATEADD(month, -53, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [v67] Blocked Container · WasteVision · open  (minsAgo=1345)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v67')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 1, N'[seed:district-demo]-2010-v67',
        DATEADD(minute, -1345, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.63544, -122.65580,
        N'1600 E 20TH ST, VANCOUVER, WA',
        N'ROSE VILLAGE COMMUNITY CENTER', N'2010-4437509',
        N'CLARK Z2', N'BIN-37551', N'Commercial', N'Linked',
        N'Access blocked, stop skipped on this pass.', N'080', N'WO-2010-113109', N'Vehicle parked in front of the enclosure.',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -119, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v68] Not Out · 3rd Eye · open  (minsAgo=1519)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v68')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 2, N'[seed:district-demo]-2010-v68',
        DATEADD(minute, -1519, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.65951, -122.63009,
        N'4211 NE MINNEHAHA ST, VANCOUVER, WA',
        N'BAGLEY DOWNS DINER', N'2010-4438870',
        N'CLARK Z2', N'BIN-38812', N'Commercial', N'Linked',
        N'Container was not out for scheduled service.', N'133', N'WO-2010-113215', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Minimal', DATEADD(month, -15, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v69] Not Out · Samsara · open  (minsAgo=3156)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v69')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 4, N'[seed:district-demo]-2010-v69',
        DATEADD(minute, -3156, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.65594, -122.70130,
        N'3600 NW ST JOHNS RD, VANCOUVER, WA',
        N'FRUIT VALLEY COLD STORAGE', N'2010-4439233',
        N'CLARK Z4', N'BIN-39270', N'Industrial', N'Linked',
        N'No service performed, nothing set out.', N'084', N'WO-2010-113369', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-3.jpg"]',
        N'Severe', DATEADD(month, -143, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v70] Overloaded · 3rd Eye · open  (minsAgo=15872)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v70')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-v70',
        DATEADD(minute, -15872, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.62815, -122.67541,
        N'1005 ESTHER ST, VANCOUVER, WA',
        N'ESTHER STREET DENTAL', N'2010-4440168',
        N'CLARK Z1', N'BIN-40115', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'124', N'WO-2010-113507', N'Load spilling from the top of the bin.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Minimal', DATEADD(month, -9, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v71] Not Out · WasteVision · closed  (minsAgo=207)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v71')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 1, N'[seed:district-demo]-2010-v71',
        DATEADD(minute, -207, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.64104, -122.60122,
        N'8700 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'VANCOUVER MALL FOOD COURT', N'2010-4441780',
        N'CLARK Z2', N'BIN-41722', N'Commercial', N'Linked',
        N'Container was not out for scheduled service.', N'005', N'WO-2010-113629', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-6.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -167, GETUTCDATE()),
        1, DATEADD(minute, -162, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [v72] Not Out · WasteVision · open  (minsAgo=2764)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v72')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 1, N'[seed:district-demo]-2010-v72',
        DATEADD(minute, -2764, GETUTCDATE()),
        N'2010-152 REL', N'VR418', 45.59775, -122.57858,
        N'9105 SE EVERGREEN HWY, VANCOUVER, WA',
        N'EVERGREEN HIGHWAY GARDENS', N'2010-4442391',
        N'CLARK Z3', N'BIN-42350', N'Commercial', N'Linked',
        N'Container was not out for scheduled service.', N'162', N'WO-2010-113750', N'Bin still inside the locked enclosure.',
        1.00, N'/event-photos/truck-cam-6.jpg',
        N'["/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Severe', DATEADD(month, -38, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [v73] Not Out · WasteVision · closed  (minsAgo=524)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v73')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 1, N'[seed:district-demo]-2010-v73',
        DATEADD(minute, -524, GETUTCDATE()),
        N'2010-152 REL', N'VR215', 45.67053, -122.68229,
        N'1201 NW 78TH ST, VANCOUVER, WA',
        N'WEST HAZEL DELL LAUNDROMAT', N'2010-4443604',
        N'CLARK Z4', N'BIN-43668', N'Commercial', N'Linked',
        N'No service performed, nothing set out.', N'051', N'WO-2010-113925', N'Cart set out after the truck cleared the stop.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Minimal', DATEADD(month, -21, GETUTCDATE()),
        1, DATEADD(minute, -479, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VR215","service":"REAR LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [v74] Contamination · WasteVision · open  (minsAgo=10211)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v74')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 1, N'[seed:district-demo]-2010-v74',
        DATEADD(minute, -10211, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.75468, -122.66679,
        N'17402 NE DELFEL RD, RIDGEFIELD, WA',
        N'CLARK COUNTY FAIRGROUNDS', N'2010-4445019',
        N'CLARK Z6', N'BIN-45072', N'Commercial', N'Linked',
        N'Load rejected for contamination at the stop.', N'137', N'WO-2010-114028', N'Recycle load shows plastic film and food waste.',
        1.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -188, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [v75] Overloaded · WasteVision · open  (minsAgo=220)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v75')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v75',
        DATEADD(minute, -220, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.64042, -122.67141,
        N'2506 MAIN ST, VANCOUVER, WA',
        N'ARNADA HOUSE APARTMENTS', N'2010-4446238',
        N'CLARK Z1', N'BIN-46200', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'107', N'WO-2010-114139', N'Load spilling from the top of the bin.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Severe', DATEADD(month, -33, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [v76] Contamination · Manual · charged  (minsAgo=297)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v76')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 3, N'[seed:district-demo]-2010-v76',
        DATEADD(minute, -297, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.63712, -122.69169,
        N'2801 W 24TH ST, VANCOUVER, WA',
        N'LINCOLN NEIGHBORHOOD GROCERY', N'2010-4447512',
        N'CLARK Z1', N'BIN-47551', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'051', N'WO-2010-114317', N'Recycle load shows plastic film and food waste.',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-8.jpg"]',
        N'Minimal', DATEADD(month, -46, GETUTCDATE()),
        1, DATEADD(minute, -252, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v77] Extra · WasteVision · open  (minsAgo=54)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v77')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v77',
        DATEADD(minute, -54, GETUTCDATE()),
        N'2010-145 FEL', N'VA108', 45.63469, -122.67310,
        N'1900 MAIN ST, VANCOUVER, WA',
        N'HOUGH TIRE AND AUTO', N'2010-4448903',
        N'CLARK Z1', N'BIN-48940', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'115', N'WO-2010-114476', N'Extra cardboard bales left at the dock.',
        3.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-2.jpg"]',
        N'Severe', DATEADD(month, -72, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [v78] Overloaded · WasteVision · charged  (minsAgo=2963)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v78')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-v78',
        DATEADD(minute, -2963, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.66466, -122.54820,
        N'12009 NE 99TH ST, VANCOUVER, WA',
        N'WALNUT GROVE BUSINESS PARK', N'2010-4450226',
        N'CLARK Z3', N'BIN-50218', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'013', N'WO-2010-114633', N'Lid propped open, load above the rails.',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-8.jpg"]',
        N'Severe', DATEADD(month, -64, GETUTCDATE()),
        1, DATEADD(minute, -2918, GETUTCDATE()), N'Priya.Raman',
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v79] Extra · WasteVision · charged  (minsAgo=2048)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v79')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-v79',
        DATEADD(minute, -2048, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.60366, -122.50335,
        N'3510 SE 164TH AVE, VANCOUVER, WA',
        N'FISHERS LANDING TRANSIT CENTER', N'2010-4452007',
        N'CLARK Z3', N'BIN-52033', N'Commercial', N'Linked',
        N'Additional set-out recorded by the driver.', N'149', N'WO-2010-114700', N'Overflow cart set out at the curb, not on service.',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-7.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Severe', DATEADD(month, -91, GETUTCDATE()),
        1, DATEADD(minute, -2003, GETUTCDATE()), N'Marcus.Lee',
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [v80] Blocked Container · Manual · open  (minsAgo=1869)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v80')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 4, 3, N'[seed:district-demo]-2010-v80',
        DATEADD(minute, -1869, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.60966, -122.56313,
        N'1301 SE ELLSWORTH RD, VANCOUVER, WA',
        N'ELLSWORTH SPRINGS TOWNHOMES', N'2010-4453118',
        N'CLARK Z3', N'BIN-53177', N'Commercial', N'Linked',
        N'Access blocked, stop skipped on this pass.', N'047', N'WO-2010-114828', N'Gate locked, no access code on file.',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-3.jpg"]',
        N'Severe', DATEADD(month, -26, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

GO


-- [d4-wv] Overloaded · WasteVision · open  (minsAgo=187)  (duplicate pair d4)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d4-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-d4-wv',
        DATEADD(minute, -187, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.60830, -122.57710,
        N'1101 SE TECH CENTER DR, VANCOUVER, WA',
        N'GRAND CENTRAL SHOPPING', N'2010-4418115',
        N'CLARK Z3', N'BIN-18106', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'024', N'WO-2010-119444', N'Lid propped open, load above the rails.',
        1.00, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Severe', DATEADD(month, -88, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [d4-3e] Overloaded · 3rd Eye · open  (minsAgo=185)  (duplicate pair d4)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d4-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-d4-3e',
        DATEADD(minute, -185, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.60833, -122.57712,
        N'1101 SE TECH CENTER DR, VANCOUVER, WA',
        N'GRAND CENTRAL SHOPPING', N'2010-4418115',
        N'CLARK Z3', N'BIN-18106', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'024', N'WO-2010-119445', N'Lid propped open, load above the rails.',
        1.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-11.jpg"]',
        N'Severe', DATEADD(month, -88, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [d5-wv] Extra · WasteVision · open  (minsAgo=640)  (duplicate pair d5)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d5-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-d5-wv',
        DATEADD(minute, -640, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.67080, -122.55510,
        N'11002 NE 117TH AVE, VANCOUVER, WA',
        N'ORCHARDS FEED AND SUPPLY', N'2010-4426082',
        N'CLARK Z3', N'BIN-26018', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'025', N'WO-2010-119455', N'Two extra toters staged beside the enclosure.',
        2.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Severe', DATEADD(month, -96, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [d5-3e] Extra · 3rd Eye · open  (minsAgo=637)  (duplicate pair d5)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d5-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-d5-3e',
        DATEADD(minute, -637, GETUTCDATE()),
        N'2010-163 ROL', N'RO101', 45.67083, -122.55512,
        N'11002 NE 117TH AVE, VANCOUVER, WA',
        N'ORCHARDS FEED AND SUPPLY', N'2010-4426082',
        N'CLARK Z3', N'BIN-26018', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'025', N'WO-2010-119456', N'Two extra toters staged beside the enclosure.',
        2.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Severe', DATEADD(month, -96, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RO101","service":"ROLL OFF","material":"GARBAGE","day":"WEDNESDAY"}]'
    );

-- [d6-wv] Contamination · WasteVision · open  (minsAgo=1265)  (duplicate pair d6)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d6-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 1, N'[seed:district-demo]-2010-d6-wv',
        DATEADD(minute, -1265, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.60960, -122.57440,
        N'1498 SE TECH CENTER PL, VANCOUVER, WA',
        N'COLUMBIA TECH CENTER OFFICES', N'2010-4436344',
        N'CLARK Z3', N'BIN-36320', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'026', N'WO-2010-119466', N'Recycle load shows plastic film and food waste.',
        1.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -53, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [d6-3e] Contamination · 3rd Eye · open  (minsAgo=1263)  (duplicate pair d6)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d6-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 2, 2, N'[seed:district-demo]-2010-d6-3e',
        DATEADD(minute, -1263, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.60963, -122.57442,
        N'1498 SE TECH CENTER PL, VANCOUVER, WA',
        N'COLUMBIA TECH CENTER OFFICES', N'2010-4436344',
        N'CLARK Z3', N'BIN-36320', N'Commercial', N'Linked',
        N'Contaminated load photographed before dumping.', N'026', N'WO-2010-119467', N'Recycle load shows plastic film and food waste.',
        1.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-13.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Minimal', DATEADD(month, -53, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [d7-wv] Overloaded · WasteVision · open  (minsAgo=2480)  (duplicate pair d7)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d7-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'[seed:district-demo]-2010-d7-wv',
        DATEADD(minute, -2480, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.64040, -122.60080,
        N'8700 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'VANCOUVER MALL FOOD COURT', N'2010-4441780',
        N'CLARK Z2', N'BIN-41722', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'027', N'WO-2010-119477', N'Lid propped open, load above the rails.',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-8.jpg"]',
        N'Severe', DATEADD(month, -167, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [d7-3e] Overloaded · 3rd Eye · open  (minsAgo=2477)  (duplicate pair d7)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d7-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'[seed:district-demo]-2010-d7-3e',
        DATEADD(minute, -2477, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.64043, -122.60082,
        N'8700 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'VANCOUVER MALL FOOD COURT', N'2010-4441780',
        N'CLARK Z2', N'BIN-41722', N'Commercial', N'Linked',
        N'Overloaded container recorded on the route camera.', N'027', N'WO-2010-119478', N'Lid propped open, load above the rails.',
        1.00, N'/event-photos/truck-cam-8.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Severe', DATEADD(month, -167, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [d8-wv] Extra · WasteVision · open  (minsAgo=4055)  (duplicate pair d8)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d8-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'[seed:district-demo]-2010-d8-wv',
        DATEADD(minute, -4055, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.66520, -122.54770,
        N'12009 NE 99TH ST, VANCOUVER, WA',
        N'WALNUT GROVE BUSINESS PARK', N'2010-4450226',
        N'CLARK Z3', N'BIN-50218', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'028', N'WO-2010-119488', N'Two extra toters staged beside the enclosure.',
        2.00, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -64, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [d8-3e] Extra · 3rd Eye · open  (minsAgo=4053)  (duplicate pair d8)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d8-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'[seed:district-demo]-2010-d8-3e',
        DATEADD(minute, -4053, GETUTCDATE()),
        N'2010-171 FEL', N'VA604', 45.66523, -122.54772,
        N'12009 NE 99TH ST, VANCOUVER, WA',
        N'WALNUT GROVE BUSINESS PARK', N'2010-4450226',
        N'CLARK Z3', N'BIN-50218', N'Commercial', N'Linked',
        N'Extra volume beyond contracted service level.', N'028', N'WO-2010-119489', N'Two extra toters staged beside the enclosure.',
        2.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Minimal', DATEADD(month, -64, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );

-- [d9-wv] Not Out · WasteVision · open  (minsAgo=5720)  (duplicate pair d9)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d9-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 1, N'[seed:district-demo]-2010-d9-wv',
        DATEADD(minute, -5720, GETUTCDATE()),
        N'2010-158 RSL', N'VR418', 45.63350, -122.53120,
        N'13519 NE 28TH ST, VANCOUVER, WA',
        N'DELACRUZ, MARTIN', N'2010-4465209',
        N'CLARK RES Z6', N'BIN-65240', N'Residential', N'Not linked',
        N'Container was not out for scheduled service.', N'029', N'WO-2010-119499', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -17, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [d9-3e] Not Out · 3rd Eye · open  (minsAgo=5717)  (duplicate pair d9)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-d9-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Details, Stop, WorkOrderNumber, TabletNotes,
        Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 5, 2, N'[seed:district-demo]-2010-d9-3e',
        DATEADD(minute, -5717, GETUTCDATE()),
        N'2010-158 RSL', N'VR418', 45.63353, -122.53122,
        N'13519 NE 28TH ST, VANCOUVER, WA',
        N'DELACRUZ, MARTIN', N'2010-4465209',
        N'CLARK RES Z6', N'BIN-65240', N'Residential', N'Not linked',
        N'Container was not out for scheduled service.', N'029', N'WO-2010-119500', N'No cart at the curb at time of service.',
        1.00, N'/event-photos/truck-cam-5.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-4.jpg"]',
        N'Minimal', DATEADD(month, -17, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR418","service":"REAR LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

GO


-- ============================================================
-- SECTION 5 — RouteEvents: district 2010-M (Vancouver Minimal)
--
-- Identical dataset; severity is overridden to 'Minimal' for all events.
-- External-id: [seed:district-demo]-2010-M-{key}
-- Account:     2010-M-{suffix}
-- ============================================================

-- [c1-wv] Overloaded · WasteVision · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c1-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 3, 1, N'[seed:district-demo]-2010-M-c1-wv',
        DATEADD(minute, -132, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.6387, -122.6615,
        N'7720 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'CASCADE STATION RETAIL', N'2010-M-4410092',
        N'CLARK Z2', N'BIN-20115', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-6.jpg',
        N'["/event-photos/truck-cam-1.jpg","/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Minimal', DATEADD(month, -103, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [c1-3e] Overloaded · 3rd Eye · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c1-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 3, 2, N'[seed:district-demo]-2010-M-c1-3e',
        DATEADD(minute, -129, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.63872, -122.66148,
        N'7720 NE VANCOUVER MALL DR, VANCOUVER, WA',
        N'CASCADE STATION RETAIL', N'2010-M-4410092',
        N'CLARK Z2', N'BIN-20115', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-9.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-2.jpg"]',
        N'Minimal', DATEADD(month, -103, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA406","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [c2-wv] Extra · WasteVision · charged
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 1, 1, N'[seed:district-demo]-2010-M-c2-wv',
        DATEADD(minute, -425, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.628, -122.674,
        N'3311 MAIN ST, VANCOUVER, WA',
        N'UPTOWN LOFTS', N'2010-M-4433001',
        N'CLARK Z1', N'BIN-31200', N'Commercial', N'Linked',
        2.00, N'/event-photos/truck-cam-1.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-10.jpg"]',
        N'Minimal', DATEADD(month, -16, GETUTCDATE()),
        1, DATEADD(minute, -380, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [c2-3e] Extra · 3rd Eye · closed
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 1, 2, N'[seed:district-demo]-2010-M-c2-3e',
        DATEADD(minute, -423, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.62803, -122.67395,
        N'3311 MAIN ST, VANCOUVER, WA',
        N'UPTOWN LOFTS', N'2010-M-4433001',
        N'CLARK Z1', N'BIN-31200', N'Commercial', N'Linked',
        2.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-1.jpg"]',
        N'Minimal', DATEADD(month, -16, GETUTCDATE()),
        1, DATEADD(minute, -378, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [c3-wv] Contamination · WasteVision · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c3-wv')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 2, 1, N'[seed:district-demo]-2010-M-c3-wv',
        DATEADD(minute, -1510, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.6512, -122.6021,
        N'9812 NE FOURTH PLAIN BLVD, VANCOUVER, WA',
        N'ORCHARDS MARKETPLACE', N'2010-M-4471180',
        N'CLARK Z3', N'BIN-44518', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -58, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"},{"code":"VA202","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [c3-3e] Contamination · 3rd Eye · open  (90450 s)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c3-3e')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 2, 2, N'[seed:district-demo]-2010-M-c3-3e',
        DATEADD(second, -90450, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.65123, -122.60205,
        N'9812 NE FOURTH PLAIN BLVD, VANCOUVER, WA',
        N'ORCHARDS MARKETPLACE', N'2010-M-4471180',
        N'CLARK Z3', N'BIN-44518', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Minimal', DATEADD(month, -58, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"},{"code":"VA202","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [s1] Blocked Container · WasteVision · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 4, 1, N'[seed:district-demo]-2010-M-s1',
        DATEADD(minute, -220, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.6231, -122.6698,
        N'415 W 8TH ST, VANCOUVER, WA',
        N'COLUMBIA CENTER OFFICES', N'2010-M-4408831',
        N'CLARK Z1', N'BIN-11842', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -87, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"}]'
    );

-- [s2] Not Out · 3rd Eye · closed
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 5, 2, N'[seed:district-demo]-2010-M-s2',
        DATEADD(minute, -2930, GETUTCDATE()),
        N'2010-133 RSL', N'VR122', 45.6119, -122.5567,
        N'11605 SE MILL PLAIN BLVD, VANCOUVER, WA',
        N'NGUYEN, DANIEL', N'2010-M-4490277',
        N'CLARK RES Z5', N'BIN-77031', N'Residential', N'Not linked',
        1.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-10.jpg","/event-photos/truck-cam-12.jpg"]',
        N'Minimal', DATEADD(month, -29, GETUTCDATE()),
        1, DATEADD(minute, -2885, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VR122","service":"REAR LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [s3] Extra · Manual · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s3')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 1, 3, N'[seed:district-demo]-2010-M-s3',
        DATEADD(minute, -95, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.6448, -122.6402,
        N'5000 E 18TH ST, VANCOUVER, WA',
        N'EVERGREEN SCHOOL DISTRICT #12', N'2010-M-4402209',
        N'CLARK Z2', N'BIN-55290', N'Commercial', N'Linked',
        3.00, N'/event-photos/truck-cam-8.jpg',
        N'["/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-11.jpg"]',
        N'Minimal', DATEADD(month, -148, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"THURSDAY"}]'
    );

-- [s4] Overloaded · WasteVision · charged
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s4')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 3, 1, N'[seed:district-demo]-2010-M-s4',
        DATEADD(minute, -1740, GETUTCDATE()),
        N'2010-121 FEL', N'VA108', 45.6055, -122.6811,
        N'100 COLUMBIA WAY, VANCOUVER, WA',
        N'WATERFRONT GRILL', N'2010-M-4455872',
        N'CLARK Z1', N'BIN-62204', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-9.jpg","/event-photos/truck-cam-6.jpg","/event-photos/truck-cam-13.jpg"]',
        N'Minimal', DATEADD(month, -41, GETUTCDATE()),
        1, DATEADD(minute, -1695, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA108","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"VA508","service":"FRONT LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [s5] Contamination · Manual · closed
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s5')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 2, 3, N'[seed:district-demo]-2010-M-s5',
        DATEADD(minute, -4310, GETUTCDATE()),
        N'2010-127 REL', N'VR310', 45.6591, -122.6939,
        N'2921 NW LOWER RIVER RD, VANCOUVER, WA',
        N'PORT OF VANCOUVER TERMINAL 3', N'2010-M-4419904',
        N'CLARK Z4', N'BIN-90112', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-7.jpg',
        N'["/event-photos/truck-cam-12.jpg","/event-photos/truck-cam-4.jpg"]',
        N'Minimal', DATEADD(month, -194, GETUTCDATE()),
        1, DATEADD(minute, -4265, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VR310","service":"FRONT LOAD","material":"RECYCLE","day":"WEDNESDAY"}]'
    );

-- [s6] Blocked Container · 3rd Eye · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s6')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 4, 2, N'[seed:district-demo]-2010-M-s6',
        DATEADD(minute, -305, GETUTCDATE()),
        N'2010-140 FEL', N'VA301', 45.6172, -122.6533,
        N'700 SE COLUMBIA SHORES BLVD, VANCOUVER, WA',
        N'SHORES MEDICAL PLAZA', N'2010-M-4462215',
        N'CLARK Z2', N'BIN-38855', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-13.jpg',
        N'["/event-photos/truck-cam-8.jpg","/event-photos/truck-cam-1.jpg"]',
        N'Minimal', DATEADD(month, -66, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VA301","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"}]'
    );

-- [s7] Not Out · Manual · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s7')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 5, 3, N'[seed:district-demo]-2010-M-s7',
        DATEADD(minute, -2650, GETUTCDATE()),
        N'2010-133 RSL', N'VR122', 45.6702, -122.5519,
        N'14508 NE 20TH AVE, VANCOUVER, WA',
        N'RAMIREZ, GLORIA', N'2010-M-4477310',
        N'CLARK RES Z6', N'BIN-70558', N'Residential', N'Not linked',
        1.00, N'/event-photos/truck-cam-10.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-5.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Minimal', DATEADD(month, -8, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"VR122","service":"REAR LOAD","material":"GARBAGE","day":"FRIDAY"}]'
    );

-- [s8] Extra · 3rd Eye · charged
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s8')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M'), 1, 2, N'[seed:district-demo]-2010-M-s8',
        DATEADD(minute, -55, GETUTCDATE()),
        N'2010-118 FEL', N'VA204', 45.6329, -122.5989,
        N'8802 MILL PLAIN BLVD, VANCOUVER, WA',
        N'MILL PLAIN CROSSING', N'2010-M-4425567',
        N'CLARK Z3', N'BIN-24471', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-12.jpg',
        N'["/event-photos/truck-cam-2.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -122, GETUTCDATE()),
        1, DATEADD(minute, -10, GETUTCDATE()), N'Kyle.Patrick',
        N'[{"code":"VA204","service":"FRONT LOAD","material":"GARBAGE","day":"TUESDAY"},{"code":"VA604","service":"FRONT LOAD","material":"GARBAGE","day":"SATURDAY"}]'
    );
GO

-- ============================================================
-- SECTION 6 — RouteEvents: duplicate clusters
--
-- 11 open events seeded across districts 1 (Vancouver/2010),
-- 3 (Cascade Disposal/2012), and 20 (Houston/5120).
-- Timestamps derived from at(daysAgo, hour, minute):
--   today  = CONVERT(VARCHAR(10), GETUTCDATE(), 120)  + 'T...'
--   yesterday = CONVERT(VARCHAR(10), DATEADD(day,-1,GETUTCDATE()), 120) + 'T...'
-- ============================================================

-- District 1 — cluster A (Extra, ~8:12 today, ~25 m apart)
-- DUPSEED-2010-A1  WasteVision  lat=45.6339  lng=-122.6031
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-2010-A1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 1, N'DUPSEED-2010-A1',
        CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), GETUTCDATE(), 120) + 'T08:12:00+00:00', 126),
        N'2010-118 FEL', N'VA204', 45.6339, -122.6031,
        N'11505 NE FOURTH PLAIN BLVD, VANCOUVER, WA',
        N'ORCHARDS MARKET CENTER', N'2010-4451220',
        1.00, N'/event-photos/truck-cam-1.jpg', N'[]',
        N'Severe', 0, NULL, NULL, N'[]'
    );

-- DUPSEED-2010-A2  3rd Eye  lat=45.6341  lng=-122.6032  (+2 min)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-2010-A2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 1, 2, N'DUPSEED-2010-A2',
        DATEADD(minute, 2, CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), GETUTCDATE(), 120) + 'T08:12:00+00:00', 126)),
        N'2010-121 REL', N'VA204', 45.6341, -122.6032,
        N'11505 NE FOURTH PLAIN BLVD, VANCOUVER, WA',
        N'ORCHARDS MARKET CENTER', N'2010-4451220',
        1.00, N'/event-photos/truck-cam-3.jpg', N'[]',
        N'Severe', 0, NULL, NULL, N'[]'
    );

-- District 1 — cluster B (Overloaded, ~10:41 yesterday, ~40 m apart)
-- DUPSEED-2010-B1  3rd Eye  lat=45.6205  lng=-122.6721
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-2010-B1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 2, N'DUPSEED-2010-B1',
        CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), DATEADD(day, -1, GETUTCDATE()), 120) + 'T10:41:00+00:00', 126),
        N'2010-121 REL', N'VR310', 45.6205, -122.6721,
        N'1015 COLUMBIA ST, VANCOUVER, WA',
        N'WATERFRONT COMMONS HOA', N'2010-4462818',
        1.00, N'/event-photos/truck-cam-5.jpg', N'[]',
        N'Minimal', 0, NULL, NULL, N'[]'
    );

-- DUPSEED-2010-B2  WasteVision  lat=45.6202  lng=-122.6719  (+3 min)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-2010-B2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2010'), 3, 1, N'DUPSEED-2010-B2',
        DATEADD(minute, 3, CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), DATEADD(day, -1, GETUTCDATE()), 120) + 'T10:41:00+00:00', 126)),
        N'2010-118 FEL', N'VR310', 45.6202, -122.6719,
        N'1015 COLUMBIA ST, VANCOUVER, WA',
        N'WATERFRONT COMMONS HOA', N'2010-4462818',
        1.00, N'/event-photos/truck-cam-6.jpg', N'[]',
        N'Minimal', 0, NULL, NULL, N'[]'
    );

-- District 3 — cluster A (Extra, ~9:27 today, ~30 m apart)
-- DUPSEED-2012-A1  WasteVision  lat=44.0582  lng=-121.3011
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-2012-A1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2012'), 1, 1, N'DUPSEED-2012-A1',
        CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), GETUTCDATE(), 120) + 'T09:27:00+00:00', 126),
        N'2012-207 FEL', N'BD102', 44.0582, -121.3011,
        N'61249 S HWY 97, BEND, OR',
        N'PONDEROSA PLAZA', N'2012-5530417',
        2.00, N'/event-photos/truck-cam-2.jpg', N'[]',
        N'Severe', 0, NULL, NULL, N'[]'
    );

-- DUPSEED-2012-A2  3rd Eye  lat=44.05845  lng=-121.3009  (+2 min)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-2012-A2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'2012'), 1, 2, N'DUPSEED-2012-A2',
        DATEADD(minute, 2, CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), GETUTCDATE(), 120) + 'T09:27:00+00:00', 126)),
        N'2012-211 FEL', N'BD102', 44.05845, -121.3009,
        N'61249 S HWY 97, BEND, OR',
        N'PONDEROSA PLAZA', N'2012-5530417',
        2.00, N'/event-photos/truck-cam-4.jpg', N'[]',
        N'Severe', 0, NULL, NULL, N'[]'
    );

-- District 20 — cluster A (Overloaded triple, ~7:58 today, within ~45 m)
-- DUPSEED-5120-A1  WasteVision  lat=29.7433  lng=-95.3921
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-5120-A1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'5120'), 3, 1, N'DUPSEED-5120-A1',
        CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), GETUTCDATE(), 120) + 'T07:58:00+00:00', 126),
        N'5120-2302 FEL', N'NY605', 29.7433, -95.3921,
        N'3800 SOUTHWEST FWY, HOUSTON, TX',
        N'GREENWAY COMMONS', N'5120-7791340',
        1.00, N'/event-photos/truck-cam-7.jpg', N'[]',
        N'Severe', 0, NULL, NULL, N'[]'
    );

-- DUPSEED-5120-A2  3rd Eye  lat=29.7435  lng=-95.3918  (+2 min)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-5120-A2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'5120'), 3, 2, N'DUPSEED-5120-A2',
        DATEADD(minute, 2, CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), GETUTCDATE(), 120) + 'T07:58:00+00:00', 126)),
        N'5120-2311 FEL', N'NY605', 29.7435, -95.3918,
        N'3800 SOUTHWEST FWY, HOUSTON, TX',
        N'GREENWAY COMMONS', N'5120-7791340',
        1.00, N'/event-photos/truck-cam-1.jpg', N'[]',
        N'Severe', 0, NULL, NULL, N'[]'
    );

-- DUPSEED-5120-A3  WasteVision  lat=29.7431  lng=-95.3920  (+3 min)  no image
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-5120-A3')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'5120'), 3, 1, N'DUPSEED-5120-A3',
        DATEADD(minute, 3, CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), GETUTCDATE(), 120) + 'T07:58:00+00:00', 126)),
        N'5120-2315 REL', N'NY605', 29.7431, -95.3920,
        N'3800 SOUTHWEST FWY, HOUSTON, TX',
        N'GREENWAY COMMONS', N'5120-7791340',
        1.00, NULL, N'[]',
        N'Severe', 0, NULL, NULL, N'[]'
    );

-- District 20 — cluster B (Extra pair, ~12:06 yesterday, ~33 m apart)
-- DUPSEED-5120-B1  3rd Eye  lat=29.8171  lng=-95.4009
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-5120-B1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'5120'), 1, 2, N'DUPSEED-5120-B1',
        CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), DATEADD(day, -1, GETUTCDATE()), 120) + 'T12:06:00+00:00', 126),
        N'5120-2311 FEL', N'RC201', 29.8171, -95.4009,
        N'8820 AIRLINE DR, HOUSTON, TX',
        N'AIRLINE FARMERS MARKET', N'5120-7735602',
        1.00, N'/event-photos/truck-cam-4.jpg', N'[]',
        N'Minimal', 0, NULL, NULL, N'[]'
    );

-- DUPSEED-5120-B2  WasteVision  lat=29.8174  lng=-95.4011  (+3 min)
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'DUPSEED-5120-B2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, Quantity, ImageUrl, ImageUrls,
        Severity, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'5120'), 1, 1, N'DUPSEED-5120-B2',
        DATEADD(minute, 3, CONVERT(DATETIMEOFFSET,
            CONVERT(VARCHAR(10), DATEADD(day, -1, GETUTCDATE()), 120) + 'T12:06:00+00:00', 126)),
        N'5120-2309 FEL', N'RC201', 29.8174, -95.4011,
        N'8820 AIRLINE DR, HOUSTON, TX',
        N'AIRLINE FARMERS MARKET', N'5120-7735602',
        1.00, N'/event-photos/truck-cam-2.jpg', N'[]',
        N'Minimal', 0, NULL, NULL, N'[]'
    );
GO

-- ============================================================
-- SECTION 7 — EventActions
--
-- One helper pattern per event that has actions.  Every block
-- checks for the target EventActions row before inserting.
--
-- note  action: dateCreated = DateOccurred + 20 min
-- close action: dateCreated = DateClosed   (DateOccurred + 45 min)
-- charge action (isFinal=1): same as close
-- history charge (isFinal=0): dateCreated = daysAgo(N, 3 h)
--
-- The district-2010-M events receive identical actions, so each
-- block is repeated for both external-id prefixes.
-- ============================================================

-- ---- c1-wv  (history: 12d $60 PAID, 41d $60 PAID, 77d $70 REFUNDED) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-c1-wv'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -12, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c1-wv';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -41, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c1-wv';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -77, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c1-wv';
END

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-c1-wv'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -12, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c1-wv';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -41, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c1-wv';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -77, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c1-wv';
END
GO

-- ---- c2-wv  (note + final charge $70 EXTRA-COM + history: 25d $70 PAID, 58d $70 PAID) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-c2-wv'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Customer called ahead about extra bags; charge approved by CSR.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -405, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c2-wv';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-c2-wv'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 2.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -380, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-c2-wv';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-c2-wv'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -25, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c2-wv';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -58, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c2-wv';
END

-- 2010-M mirror
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-c2-wv'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Customer called ahead about extra bags; charge approved by CSR.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -405, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-wv';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-c2-wv'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M') AND Code = N'EXTRA-COM'),
           70.0000, 2.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -380, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-wv';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-c2-wv'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -25, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-wv';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -58, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-wv';
END
GO

-- ---- c2-3e  (note + final close "Duplicate Event") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-c2-3e'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Duplicate of WasteVision report at same address; closing.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -403, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c2-3e';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-c2-3e'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Duplicate Event', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -378, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c2-3e';

-- 2010-M mirror
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-c2-3e'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Duplicate of WasteVision report at same address; closing.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -403, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-3e';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-c2-3e'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Duplicate Event', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -378, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c2-3e';
GO

-- ---- c3-wv  (history: 19d $90 PAID) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-c3-wv'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 90.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE()))
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-c3-wv';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-c3-wv'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 90.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE()))
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-c3-wv';
GO

-- ---- s1  (history: 33d $15 PAID) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s1'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 15.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -33, GETUTCDATE()))
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s1';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s1'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 15.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -33, GETUTCDATE()))
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s1';
GO

-- ---- s2  (note + final close "Not an Overfill") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s2'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Cart was out by the time the follow-up truck arrived.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -2910, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s2';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s2'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Not an Overfill', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -2885, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s2';

-- 2010-M mirror
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s2'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Cart was out by the time the follow-up truck arrived.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -2910, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s2';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s2'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Not an Overfill', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -2885, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s2';
GO

-- ---- s3  (note only) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s3'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Driver reported extra pallets of boxed waste at loading dock.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -75, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s3';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s3'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Driver reported extra pallets of boxed waste at loading dock.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -75, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s3';
GO

-- ---- s4  (note + final charge $60 OVERLOAD + history: 14d $60 PAID, 49d $60 NULL, 83d $60 PAID) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s4'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Lid open >45 degrees, photos confirm overload.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -1720, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s4';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s4'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'OVERLOAD'),
           60.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -1695, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-s4';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s4'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -14, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s4';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, NULL,     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -49, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s4';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -83, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s4';
END

-- 2010-M mirror
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s4'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Lid open >45 degrees, photos confirm overload.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -1720, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s4';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s4'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M') AND Code = N'OVERLOAD'),
           60.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -1695, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-M-s4';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s4'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -14, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s4';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, NULL,     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -49, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s4';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -83, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s4';
END
GO

-- ---- s5  (note + final close "Courtesy Close") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s5'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'First contamination event for this account; courtesy close.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -4290, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s5';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s5'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Courtesy Close', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -4265, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s5';

-- 2010-M mirror
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s5'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'First contamination event for this account; courtesy close.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -4290, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s5';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s5'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Courtesy Close', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -4265, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s5';
GO

-- ---- s8  (note + final charge $70 EXTRA-COM + history: 22d $70 PAID, 51d $70 REFUNDED, 88d $70 PAID) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s8'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Recurring extra volume; recommended service level review.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -35, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s8';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s8'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -10, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-s8';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-s8'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -22, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s8';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -51, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s8';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -88, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-s8';
END

-- 2010-M mirror
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s8'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Recurring extra volume; recommended service level review.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -35, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s8';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s8'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010-M') AND Code = N'EXTRA-COM'),
           70.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -10, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-M-s8';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-M-s8'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -22, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s8';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -51, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s8';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID',     N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -88, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-M-s8';
END
GO

-- ============================================================
-- SECTION 7 — Samsara-sourced events (district 5120, Houston)
--
-- The Samsara camera vendor had no events of its own, so its mark
-- never appeared in the grid. These two rows give it a presence in
-- the district charge agents actually work in. Same guard as every
-- other row here: re-running the script adds them once and then
-- leaves them alone.
-- ============================================================

-- [sam-1] Contamination · Samsara · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-5120-sam-1')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'5120'), 2, 4, N'[seed:district-demo]-5120-sam-1',
        DATEADD(minute, -96, GETUTCDATE()),
        N'5120-2311 FEL', N'RC201', 29.8612, -95.3982,
        N'8820 AIRLINE DR, HOUSTON, TX',
        N'AIRLINE FARMERS MARKET', N'5120-7735602',
        N'HOU Z4', N'BIN-90140', N'Commercial', N'Linked',
        1.00, N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-3.jpg","/event-photos/truck-cam-9.jpg"]',
        N'Severe', DATEADD(month, -47, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"RC201","service":"FRONT LOAD","material":"GARBAGE","day":"MONDAY"},{"code":"RC118","service":"FRONT LOAD","material":"RECYCLE","day":"THURSDAY"}]'
    );

-- [sam-2] Extra · Samsara · open
IF NOT EXISTS (SELECT 1 FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-5120-sam-2')
    INSERT INTO dbo.RouteEvents (
        DistrictId, EventTypeId, EventSourceId, ExternalId,
        DateOccurred, Vehicle, Route, Latitude, Longitude, Address,
        CustomerName, AccountNumber, BillArea, BinSerialNumber,
        Lob, RmoStatus, Quantity, ImageUrl, ImageUrls,
        Severity, CustomerSince, EventStatus, DateClosed, ClosedBy, CustomerRoutes
    ) VALUES (
        (SELECT Id FROM dbo.Districts WHERE Number = N'5120'), 1, 4, N'[seed:district-demo]-5120-sam-2',
        DATEADD(minute, -211, GETUTCDATE()),
        N'5120-2309 FEL', N'NY109', 29.8894, -95.4121,
        N'4403 NORTH FWY, HOUSTON, TX',
        N'NORTH FWY STORAGE', N'5120-7786472',
        N'HOU Z2', N'R6-295', N'Commercial', N'Linked',
        2.00, N'/event-photos/truck-cam-11.jpg',
        N'["/event-photos/truck-cam-11.jpg","/event-photos/truck-cam-4.jpg","/event-photos/truck-cam-7.jpg"]',
        N'Minimal', DATEADD(month, -18, GETUTCDATE()),
        0, NULL, NULL,
        N'[{"code":"NY109","service":"FRONT LOAD","material":"GARBAGE","day":"WEDNESDAY"}]'
    );
GO

-- ============================================================
-- SECTION 8 — EventActions: district 2010 volume dataset
--
-- Actions for the SECTION 4B rows, using the same guard style as
-- SECTION 7: every block checks for its own target row first, so a
-- re-run inserts nothing.
--
-- note   action: dateCreated = DateOccurred + 20 min
-- close  action (isFinal=1): dateCreated = DateClosed
-- charge action (isFinal=1): dateCreated = DateClosed
-- history charge (isFinal=0): dateCreated = daysAgo(N, 3 h) — gives
--   the event-detail statistics section prior charges to summarise.
-- ============================================================

-- ---- v02  (note + final charge $70 EXTRA-COM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v02'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Extra volume confirmed on the route camera; charge approved.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -4205, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v02';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v02'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 4.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -4180, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v02';

-- ---- v06  (note + final charge $60 OVERLOAD) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v06'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Repeat overload for this account; charge applied.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -3964, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v06';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v06'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'OVERLOAD'),
           60.0000, 1.50, N'REFUNDED', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -3939, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v06';

-- ---- v07  (note + final close "New Customer") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v07'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Access cleared before the recovery truck arrived.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -8273, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v07';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v07'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'New Customer', N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -8248, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v07';

-- ---- v08  (note + final close "Duplicate") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v08'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Obstruction was a district-side scheduling conflict.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -3271, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v08';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v08'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Duplicate', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -3246, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v08';

-- ---- v11  (note + final charge $60 OVERLOAD) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v11'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Lid open past the fill line in every frame; charge applied.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -14223, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v11';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v11'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'OVERLOAD'),
           60.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -14198, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v11';

-- ---- v12  (note + final charge $70 EXTRA-COM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v12'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'CSR approved the extra pickup charge for this stop.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -3842, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v12';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v12'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 4.00, N'REFUNDED', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -3817, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v12';

-- ---- v13  (note + final charge $90 CONTAM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v13'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Load rejected at the transfer station; charge applied.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -6627, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v13';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v13'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'CONTAM'),
           90.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -6602, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v13';

-- ---- v16  (note + final charge $70 EXTRA-COM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v16'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Extra volume confirmed on the route camera; charge approved.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -253, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v16';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v16'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 2.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -228, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v16';

GO


-- ---- v17  (note + final charge $90 CONTAM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v17'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Contamination confirmed in both photos; charge applied.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -905, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v17';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v17'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'CONTAM'),
           90.0000, 1.00, NULL, N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -880, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v17';

-- ---- v22  (note + final charge $60 OVERLOAD) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v22'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Lid open past the fill line in every frame; charge applied.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -16879, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v22';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v22'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'OVERLOAD'),
           60.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -16854, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v22';

-- ---- v24  (note + final charge $90 CONTAM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v24'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Contamination confirmed in both photos; charge applied.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -1154, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v24';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v24'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'CONTAM'),
           90.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -1129, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v24';

-- ---- v27  (note + final close "District Declined to Charge") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v27'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Load was contaminated but customer corrected on site.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -6081, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v27';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v27'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'District Declined to Charge', N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -6056, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v27';

-- ---- v28  (note + final close "New Customer") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v28'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Container was within tolerance on the second look.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -431, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v28';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v28'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'New Customer', N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -406, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v28';

-- ---- v29  (note + final close "Not an Overfill") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v29'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Customer disputed the extra set-out, records agree.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -723, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v29';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v29'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Not an Overfill', N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -698, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v29';

-- ---- v37  (note + final charge $70 EXTRA-COM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v37'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'CSR approved the extra pickup charge for this stop.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -3682, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v37';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v37'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 2.00, N'REFUNDED', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -3657, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v37';

-- ---- v38  (note + final close "Duplicate") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v38'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Service point confirmed empty by the route manager.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -5170, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v38';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v38'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Duplicate', N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -5145, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v38';

GO


-- ---- v40  (note + final close "Contract - No Overages") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v40'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Access cleared before the recovery truck arrived.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -9100, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v40';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v40'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Contract - No Overages', N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -9075, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v40';

-- ---- v42  (note + final close "Contract - No Overages") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v42'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Service point confirmed empty by the route manager.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -824, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v42';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v42'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Contract - No Overages', N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -799, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v42';

-- ---- v43  (note + final close "Contract - No Overages") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v43'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Obstruction was a district-side scheduling conflict.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -4450, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v43';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v43'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Contract - No Overages', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -4425, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v43';

-- ---- v44  (note + final close "Duplicate") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v44'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Customer disputed the extra set-out, records agree.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -103, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v44';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v44'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Duplicate', N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -78, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v44';

-- ---- v46  (note + final close "Contract - No Overages") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v46'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Load was contaminated but customer corrected on site.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -5397, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v46';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v46'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Contract - No Overages', N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -5372, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v46';

-- ---- v48  (note + final close "District Declined to Charge") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v48'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Verified against tablet photos; no extra service rendered.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -2223, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v48';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v48'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'District Declined to Charge', N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -2198, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v48';

-- ---- v49  (note + final close "Not an Overfill") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v49'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'First contamination for this account this quarter.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -9741, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v49';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v49'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Not an Overfill', N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -9716, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v49';

-- ---- v51  (note + final close "New Customer") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v51'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Fill line reviewed with the route supervisor.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -4129, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v51';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v51'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'New Customer', N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -4104, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v51';

GO


-- ---- v52  (note + final charge $70 EXTRA-COM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v52'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'CSR approved the extra pickup charge for this stop.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -222, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v52';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v52'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Dana.Whitfield', DATEADD(minute, -197, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v52';

-- ---- v53  (note + final close "District Declined to Charge") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v53'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Load was contaminated but customer corrected on site.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -1569, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v53';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v53'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'District Declined to Charge', N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -1544, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v53';

-- ---- v57  (note + final charge $60 OVERLOAD) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v57'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Repeat overload for this account; charge applied.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -2425, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v57';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v57'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'OVERLOAD'),
           60.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Sofia.Alvarez', DATEADD(minute, -2400, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v57';

-- ---- v71  (note + final close "District Declined to Charge") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v71'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Cart was out by the time the follow-up truck arrived.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -187, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v71';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v71'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'District Declined to Charge', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -162, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v71';

-- ---- v73  (note + final close "Not an Overfill") ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v73'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Cart was out by the time the follow-up truck arrived.',
           N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -504, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v73';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v73'
      AND ea.ActionType = N'close' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, CloseReason, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'close', 1, N'Not an Overfill', N'[seed:district-demo]', N'Kyle.Patrick', DATEADD(minute, -479, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v73';

-- ---- v76  (note + final charge $90 CONTAM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v76'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Contamination confirmed in both photos; charge applied.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -277, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v76';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v76'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'CONTAM'),
           90.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -252, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v76';

-- ---- v78  (note + final charge $60 OVERLOAD) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v78'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'Lid open past the fill line in every frame; charge applied.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -2943, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v78';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v78'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'OVERLOAD'),
           60.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Priya.Raman', DATEADD(minute, -2918, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v78';

-- ---- v79  (note + final charge $70 EXTRA-COM) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v79'
      AND ea.ActionType = N'note'
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'note', 0, N'CSR approved the extra pickup charge for this stop.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -2028, GETUTCDATE())
    FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v79';

IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v79'
      AND ea.ActionType = N'charge' AND ea.IsFinal = 1
)
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ServiceCodeId, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT re.Id, N'charge', 1,
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = (SELECT Id FROM dbo.Districts WHERE Number = N'2010') AND Code = N'EXTRA-COM'),
           70.0000, 1.00, N'PAID', N'Overage charge applied to account.',
           N'[seed:district-demo]', N'Marcus.Lee', DATEADD(minute, -2003, GETUTCDATE())
    FROM dbo.RouteEvents re WHERE ExternalId = N'[seed:district-demo]-2010-v79';

GO

-- ---- v02  (prior charge history · account 2010-4413771) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v02'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -15, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v02';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -34, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v02';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -70, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v02';
END

-- ---- v04  (prior charge history · account 2010-4416644) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v04'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v04';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 75.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -39, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v04';
END

-- ---- v06  (prior charge history · account 2010-4418115) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v06'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -16, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v06';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -42, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v06';
END

-- ---- v11  (prior charge history · account 2010-4423915) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v11'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Priya.Raman', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v11';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Priya.Raman', DATEADD(hour, 3, DATEADD(day, -43, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v11';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Priya.Raman', DATEADD(hour, 3, DATEADD(day, -82, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v11';
END

-- ---- v12  (prior charge history · account 2010-4424318) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v12'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -18, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v12';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 80.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -36, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v12';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 80.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -76, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v12';
END

-- ---- v13  (prior charge history · account 2010-4426082) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v13'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v13';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 95.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -49, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v13';
END

-- ---- v15  (prior charge history · account 2010-4428443) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v15'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -11, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v15';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -36, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v15';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -60, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v15';
END

-- ---- v16  (prior charge history · account 2010-4429177) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v16'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -22, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v16';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -41, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v16';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 75.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -60, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v16';
END

GO


-- ---- v17  (prior charge history · account 2010-4430512) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v17'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -22, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v17';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 90.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -55, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v17';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 85.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -87, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v17';
END

-- ---- v20  (prior charge history · account 2010-4434128) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v20'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 80.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -14, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v20';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 75.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -54, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v20';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -73, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v20';
END

-- ---- v22  (prior charge history · account 2010-4436344) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v22'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -18, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v22';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -59, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v22';
END

-- ---- v24  (prior charge history · account 2010-4438870) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v24'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v24';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -52, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v24';
END

-- ---- v26  (prior charge history · account 2010-4440168) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v26'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -9, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v26';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Dana.Whitfield', DATEADD(hour, 3, DATEADD(day, -32, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v26';
END

-- ---- v27  (prior charge history · account 2010-4441780) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v27'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v27';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 95.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -43, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v27';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -67, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v27';
END

-- ---- v30  (prior charge history · account 2010-4445019) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v30'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -10, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v30';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 75.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -34, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v30';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -61, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v30';
END

-- ---- v31  (prior charge history · account 2010-4446238) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v31'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -14, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v31';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 90.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -55, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v31';
END

GO


-- ---- v32  (prior charge history · account 2010-4447512) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v32'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 75.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -9, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v32';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Sofia.Alvarez', DATEADD(hour, 3, DATEADD(day, -27, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v32';
END

-- ---- v35  (prior charge history · account 2010-4452007) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v35'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 85.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -21, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v35';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 90.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -54, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v35';
END

-- ---- v37  (prior charge history · account 2010-4460114) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v37'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 75.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -9, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v37';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -37, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v37';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 70.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -65, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v37';
END

-- ---- v41  (prior charge history · account 2010-4464820) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v41'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 80.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -14, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v41';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -55, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v41';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Marcus.Lee', DATEADD(hour, 3, DATEADD(day, -92, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v41';
END

-- ---- v43  (prior charge history · account 2010-4466711) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v43'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -15, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v43';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 85.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -56, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v43';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 100.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -88, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v43';
END

-- ---- v44  (prior charge history · account 2010-4467933) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v44'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 80.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Priya.Raman', DATEADD(hour, 3, DATEADD(day, -22, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v44';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 80.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Priya.Raman', DATEADD(hour, 3, DATEADD(day, -41, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v44';
END

-- ---- v45  (prior charge history · account 2010-4412006) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v45'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 90.0000, 1.00, NULL    , N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -14, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v45';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 90.0000, 1.00, N'REFUNDED', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Kyle.Patrick', DATEADD(hour, 3, DATEADD(day, -54, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v45';
END

-- ---- v51  (prior charge history · account 2010-4419912) ----
IF NOT EXISTS (
    SELECT 1 FROM dbo.EventActions ea
    INNER JOIN dbo.RouteEvents re ON ea.RouteEventId = re.Id
    WHERE re.ExternalId = N'[seed:district-demo]-2010-v51'
      AND ea.BilledStatementNumber = N'[seed:district-demo]-history'
)
BEGIN
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 65.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Priya.Raman', DATEADD(hour, 3, DATEADD(day, -19, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v51';
    INSERT INTO dbo.EventActions (RouteEventId, ActionType, IsFinal, ChargeAmount, ChargeQuantity, PaymentStatus, Notes, BilledStatementNumber, CreatedBy, DateCreated)
    SELECT Id, N'charge', 0, 60.0000, 1.00, N'PAID', N'Overage charge applied to account.', N'[seed:district-demo]-history', N'Priya.Raman', DATEADD(hour, 3, DATEADD(day, -56, GETUTCDATE())) FROM dbo.RouteEvents WHERE ExternalId = N'[seed:district-demo]-2010-v51';
END

GO

