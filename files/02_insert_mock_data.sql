-- ============================================================
-- 02_insert_mock_data.sql
-- Microsoft SQL Server  —  Route Events mock data seed
--
-- Populates all lookup tables and inserts the full demo dataset:
--   • EventTypes (5 rows), EventSources (3 rows)
--   • Districts (4 rows — Vancouver/2010, Vancouver-Minimal/2010-M,
--                         Cascade Disposal/2012, Houston/5120)
--   • ServiceCodes (3 codes × 2 districts)
--   • RouteEvents (14 events × 2 districts + 11 duplicate-cluster events)
--   • EventActions (notes, close, charge, and history entries)
--
-- Idempotent: every INSERT block is guarded with IF NOT EXISTS so the
-- script can be re-run safely.
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

-- ---- EventSources (IDs 1-3) --------------------------------
SET IDENTITY_INSERT dbo.EventSources ON;

IF NOT EXISTS (SELECT 1 FROM dbo.EventSources WHERE Id = 1)
    INSERT INTO dbo.EventSources (Id, Name, Active) VALUES (1, N'WasteVision', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventSources WHERE Id = 2)
    INSERT INTO dbo.EventSources (Id, Name, Active) VALUES (2, N'3rd Eye',     1);
IF NOT EXISTS (SELECT 1 FROM dbo.EventSources WHERE Id = 3)
    INSERT INTO dbo.EventSources (Id, Name, Active) VALUES (3, N'Manual',      1);

SET IDENTITY_INSERT dbo.EventSources OFF;
GO

-- ============================================================
-- SECTION 2 — Districts
-- ============================================================
SET IDENTITY_INSERT dbo.Districts ON;

-- id=1  Vancouver (2010)
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Id = 1)
    INSERT INTO dbo.Districts (Id, Number, Name, Region, HaulingSystem, Active)
    VALUES (1, N'2010', N'VANCOUVER', N'Western', 1, 1);

-- id=2  Vancouver Minimal (2010-M) — twin district, identical service area, all events shown as Minimal severity
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Id = 2)
    INSERT INTO dbo.Districts (Id, Number, Name, Region, HaulingSystem, Active)
    VALUES (2, N'2010-M', N'VANCOUVER MINIMAL', N'Western', 1, 1);

-- id=3  Cascade Disposal (2012)
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Id = 3)
    INSERT INTO dbo.Districts (Id, Number, Name, Region, HaulingSystem, Active)
    VALUES (3, N'2012', N'CASCADE DISPOSAL', N'Western', 1, 1);

-- id=20 Houston (5120)
IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE Id = 20)
    INSERT INTO dbo.Districts (Id, Number, Name, Region, HaulingSystem, Active)
    VALUES (20, N'5120', N'HOUSTON', N'Southern', 1, 1);

SET IDENTITY_INSERT dbo.Districts OFF;
GO

-- ============================================================
-- SECTION 3 — Service codes (district 1 and 2)
-- ============================================================

-- District 1 (2010)
IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = 1 AND Code = N'EXTRA-COM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES (1, N'EXTRA-COM', N'Extra pickup - Commercial', 70.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = 1 AND Code = N'CONTAM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES (1, N'CONTAM', N'Contamination charge', 90.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = 1 AND Code = N'OVERLOAD')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES (1, N'OVERLOAD', N'Overloaded container charge', 60.0000, 1);

-- District 2 (2010-M)
IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = 2 AND Code = N'EXTRA-COM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES (2, N'EXTRA-COM', N'Extra pickup - Commercial', 70.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = 2 AND Code = N'CONTAM')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES (2, N'CONTAM', N'Contamination charge', 90.0000, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.ServiceCodes WHERE DistrictId = 2 AND Code = N'OVERLOAD')
    INSERT INTO dbo.ServiceCodes (DistrictId, Code, Description, Amount, Active)
    VALUES (2, N'OVERLOAD', N'Overloaded container charge', 60.0000, 1);
GO

-- ============================================================
-- SECTION 4 — RouteEvents: district 2010 (id=1)
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
        1, 3, 1, N'[seed:district-demo]-2010-c1-wv',
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
        1, 3, 2, N'[seed:district-demo]-2010-c1-3e',
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
        1, 1, 1, N'[seed:district-demo]-2010-c2-wv',
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
        1, 1, 2, N'[seed:district-demo]-2010-c2-3e',
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
        1, 2, 1, N'[seed:district-demo]-2010-c3-wv',
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
        1, 2, 2, N'[seed:district-demo]-2010-c3-3e',
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
        1, 4, 1, N'[seed:district-demo]-2010-s1',
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
        1, 5, 2, N'[seed:district-demo]-2010-s2',
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
        1, 1, 3, N'[seed:district-demo]-2010-s3',
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
        1, 3, 1, N'[seed:district-demo]-2010-s4',
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
        1, 2, 3, N'[seed:district-demo]-2010-s5',
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
        1, 4, 2, N'[seed:district-demo]-2010-s6',
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
        1, 5, 3, N'[seed:district-demo]-2010-s7',
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
        1, 1, 2, N'[seed:district-demo]-2010-s8',
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
-- SECTION 5 — RouteEvents: district 2010-M (id=2)
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
        2, 3, 1, N'[seed:district-demo]-2010-M-c1-wv',
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
        2, 3, 2, N'[seed:district-demo]-2010-M-c1-3e',
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
        2, 1, 1, N'[seed:district-demo]-2010-M-c2-wv',
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
        2, 1, 2, N'[seed:district-demo]-2010-M-c2-3e',
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
        2, 2, 1, N'[seed:district-demo]-2010-M-c3-wv',
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
        2, 2, 2, N'[seed:district-demo]-2010-M-c3-3e',
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
        2, 4, 1, N'[seed:district-demo]-2010-M-s1',
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
        2, 5, 2, N'[seed:district-demo]-2010-M-s2',
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
        2, 1, 3, N'[seed:district-demo]-2010-M-s3',
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
        2, 3, 1, N'[seed:district-demo]-2010-M-s4',
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
        2, 2, 3, N'[seed:district-demo]-2010-M-s5',
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
        2, 4, 2, N'[seed:district-demo]-2010-M-s6',
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
        2, 5, 3, N'[seed:district-demo]-2010-M-s7',
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
        2, 1, 2, N'[seed:district-demo]-2010-M-s8',
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
        1, 1, 1, N'DUPSEED-2010-A1',
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
        1, 1, 2, N'DUPSEED-2010-A2',
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
        1, 3, 2, N'DUPSEED-2010-B1',
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
        1, 3, 1, N'DUPSEED-2010-B2',
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
        3, 1, 1, N'DUPSEED-2012-A1',
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
        3, 1, 2, N'DUPSEED-2012-A2',
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
        20, 3, 1, N'DUPSEED-5120-A1',
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
        20, 3, 2, N'DUPSEED-5120-A2',
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
        20, 3, 1, N'DUPSEED-5120-A3',
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
        20, 1, 2, N'DUPSEED-5120-B1',
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
        20, 1, 1, N'DUPSEED-5120-B2',
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
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = 1 AND Code = N'EXTRA-COM'),
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
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = 2 AND Code = N'EXTRA-COM'),
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
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = 1 AND Code = N'OVERLOAD'),
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
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = 2 AND Code = N'OVERLOAD'),
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
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = 1 AND Code = N'EXTRA-COM'),
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
           (SELECT Id FROM dbo.ServiceCodes WHERE DistrictId = 2 AND Code = N'EXTRA-COM'),
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
