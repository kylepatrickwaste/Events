-- ============================================================
-- 03_insert_nearby_overages.sql
-- Microsoft SQL Server  —  Nearby-overage demo seed
--
-- Inserts four nearby-overage events (SEED_TAG-nearby-A/B/C/X)
-- anchored to the primary demo event [seed:district-demo]-2010-c1-wv,
-- together with their event_action rows and charge/payment history
-- for the primary event's account.
--
-- Mirrors the TypeScript seed in scripts/src/seed-event-detail.ts
-- (nearbySpecs + charge history blocks).
--
-- Anchor event coordinates and metadata:
--   lat=45.6387  lng=-122.6615
--   district_id=1  event_type_id=3  event_source_id=1
--   date_occurred=DATEADD(minute,-132,GETUTCDATE())
--
-- Offsets at ~30°N: 1e-4 deg lat ≈ 11.1 m, 1e-4 deg lng ≈ 9.6 m.
--   A: ~110 m  Open    (just inside radius, no charge)
--   B: ~175 m  Charged (closed + charge action)
--   C: ~288 m  Closed  (just inside 300 m radius, close action only)
--   X: ~335 m  Open    (just OUTSIDE radius — must not appear in nearby panel)
--
-- Idempotent: every INSERT is guarded with IF NOT EXISTS on external_id.
--
-- Run order:  01_create_tables.sql
--          →  02_insert_mock_data.sql
--          →  03_insert_nearby_overages.sql
-- ============================================================

SET NOCOUNT ON;
GO

-- ============================================================
-- SECTION 1 — Nearby-overage route_events
-- ============================================================

-- [nearby-A] Open · no charge · Cascade Coffee Roasters
-- offsetSec=-540 → dateOccurred = anchor - 540 s (9 min earlier)
-- lat=45.6387+0.0009=45.6396  lng=-122.6615-0.0005=-122.6620
IF NOT EXISTS (SELECT 1 FROM dbo.route_events WHERE external_id = N'[seed:event-detail]-nearby-A')
    INSERT INTO dbo.route_events (
        district_id, event_type_id, event_source_id, external_id,
        date_occurred, vehicle, route, latitude, longitude, address,
        customer_name, account_number, bill_area, bin_serial_number,
        lob, rmo_status, quantity, image_url, image_urls,
        severity, customer_since, event_status, date_closed, closed_by, customer_routes
    )
    SELECT
        re.district_id, re.event_type_id, re.event_source_id,
        N'[seed:event-detail]-nearby-A',
        DATEADD(second, -540, re.date_occurred),
        re.vehicle, re.route,
        45.6396, -122.6620,
        re.address,
        N'Cascade Coffee Roasters', N'7-41255-33002', re.bill_area, N'BIN-88213',
        re.lob, re.rmo_status,
        1.00,
        N'/event-photos/truck-cam-2.jpg',
        N'["/event-photos/truck-cam-2.jpg"]',
        N'Minimal', DATEADD(month, -16, GETUTCDATE()),
        0, NULL, NULL,
        re.customer_routes
    FROM dbo.route_events re
    WHERE re.external_id = N'[seed:district-demo]-2010-c1-wv';

-- [nearby-B] Closed + charged · Harborview Deli & Market
-- offsetSec=+320 → dateOccurred = anchor + 320 s (5 min later)
-- lat=45.6387-0.0014=45.6373  lng=-122.6615+0.0008=-122.6607
IF NOT EXISTS (SELECT 1 FROM dbo.route_events WHERE external_id = N'[seed:event-detail]-nearby-B')
    INSERT INTO dbo.route_events (
        district_id, event_type_id, event_source_id, external_id,
        date_occurred, vehicle, route, latitude, longitude, address,
        customer_name, account_number, bill_area, bin_serial_number,
        lob, rmo_status, quantity, image_url, image_urls,
        severity, customer_since, event_status, date_closed, closed_by, customer_routes
    )
    SELECT
        re.district_id, re.event_type_id, re.event_source_id,
        N'[seed:event-detail]-nearby-B',
        DATEADD(second, 320, re.date_occurred),
        re.vehicle, re.route,
        45.6373, -122.6607,
        re.address,
        N'Harborview Deli & Market', N'7-58990-11407', re.bill_area, N'BIN-90441',
        re.lob, re.rmo_status,
        1.00,
        N'/event-photos/truck-cam-3.jpg',
        N'["/event-photos/truck-cam-3.jpg"]',
        N'Minimal', DATEADD(month, -16, GETUTCDATE()),
        1, DATEADD(day, -1, GETUTCDATE()), N'Kyle.Patrick',
        re.customer_routes
    FROM dbo.route_events re
    WHERE re.external_id = N'[seed:district-demo]-2010-c1-wv';

-- [nearby-C] Closed · no charge · same customer as anchor (CASCADE STATION RETAIL)
-- offsetSec=+1150 → dateOccurred = anchor + 1150 s (~19 min later)
-- lat=45.6387+0.002=45.6407  lng=-122.6615+0.0019=-122.6596  (just inside 300 m)
IF NOT EXISTS (SELECT 1 FROM dbo.route_events WHERE external_id = N'[seed:event-detail]-nearby-C')
    INSERT INTO dbo.route_events (
        district_id, event_type_id, event_source_id, external_id,
        date_occurred, vehicle, route, latitude, longitude, address,
        customer_name, account_number, bill_area, bin_serial_number,
        lob, rmo_status, quantity, image_url, image_urls,
        severity, customer_since, event_status, date_closed, closed_by, customer_routes
    )
    SELECT
        re.district_id, re.event_type_id, re.event_source_id,
        N'[seed:event-detail]-nearby-C',
        DATEADD(second, 1150, re.date_occurred),
        re.vehicle, re.route,
        45.6407, -122.6596,
        re.address,
        re.customer_name, re.account_number, re.bill_area, re.bin_serial_number,
        re.lob, re.rmo_status,
        1.00,
        N'/event-photos/truck-cam-4.jpg',
        N'["/event-photos/truck-cam-4.jpg"]',
        N'Minimal', re.customer_since,
        1, DATEADD(day, -1, GETUTCDATE()), N'Kyle.Patrick',
        re.customer_routes
    FROM dbo.route_events re
    WHERE re.external_id = N'[seed:district-demo]-2010-c1-wv';

-- [nearby-X] Open · no charge · Pinecrest Auto Body
-- offsetSec=+600 → dateOccurred = anchor + 600 s (10 min later)
-- lat=45.6387+0.0024=45.6411  lng=-122.6615+0.0021=-122.6594  (just OUTSIDE 300 m)
IF NOT EXISTS (SELECT 1 FROM dbo.route_events WHERE external_id = N'[seed:event-detail]-nearby-X')
    INSERT INTO dbo.route_events (
        district_id, event_type_id, event_source_id, external_id,
        date_occurred, vehicle, route, latitude, longitude, address,
        customer_name, account_number, bill_area, bin_serial_number,
        lob, rmo_status, quantity, image_url, image_urls,
        severity, customer_since, event_status, date_closed, closed_by, customer_routes
    )
    SELECT
        re.district_id, re.event_type_id, re.event_source_id,
        N'[seed:event-detail]-nearby-X',
        DATEADD(second, 600, re.date_occurred),
        re.vehicle, re.route,
        45.6411, -122.6594,
        re.address,
        N'Pinecrest Auto Body', N'7-33208-55910', re.bill_area, N'BIN-77120',
        re.lob, re.rmo_status,
        1.00,
        N'/event-photos/truck-cam-5.jpg',
        N'["/event-photos/truck-cam-5.jpg"]',
        N'Minimal', DATEADD(month, -16, GETUTCDATE()),
        0, NULL, NULL,
        re.customer_routes
    FROM dbo.route_events re
    WHERE re.external_id = N'[seed:district-demo]-2010-c1-wv';

GO

-- ============================================================
-- SECTION 2 — event_actions for the nearby closed events
-- ============================================================

-- [nearby-B] charge action (charged=true, paymentStatus=PAID)
IF NOT EXISTS (
    SELECT 1 FROM dbo.event_actions ea
    INNER JOIN dbo.route_events re ON ea.route_event_id = re.id
    WHERE re.external_id = N'[seed:event-detail]-nearby-B'
      AND ea.action_type = N'charge' AND ea.is_final = 1
)
    INSERT INTO dbo.event_actions (
        route_event_id, action_type, is_final, close_reason,
        charge_amount, charge_quantity, payment_status,
        billed_statement_number, created_by
    )
    SELECT
        re.id, N'charge', 1, NULL,
        65.0000, 1.00, N'PAID',
        N'[seed:event-detail]', N'Kyle.Patrick'
    FROM dbo.route_events re
    WHERE re.external_id = N'[seed:event-detail]-nearby-B';

-- [nearby-C] close action (charged=false, close reason = Not an Overfill)
IF NOT EXISTS (
    SELECT 1 FROM dbo.event_actions ea
    INNER JOIN dbo.route_events re ON ea.route_event_id = re.id
    WHERE re.external_id = N'[seed:event-detail]-nearby-C'
      AND ea.action_type = N'close' AND ea.is_final = 1
)
    INSERT INTO dbo.event_actions (
        route_event_id, action_type, is_final, close_reason,
        charge_amount, charge_quantity, payment_status,
        billed_statement_number, created_by
    )
    SELECT
        re.id, N'close', 1, N'Not an Overfill',
        NULL, NULL, NULL,
        N'[seed:event-detail]', N'Kyle.Patrick'
    FROM dbo.route_events re
    WHERE re.external_id = N'[seed:event-detail]-nearby-C';

GO

-- ============================================================
-- SECTION 3 — Charge/payment history for the anchor event
--             (account 2010-4410092, last 12/38/55/82 days)
-- ============================================================

IF NOT EXISTS (
    SELECT 1 FROM dbo.event_actions ea
    INNER JOIN dbo.route_events re ON ea.route_event_id = re.id
    WHERE re.external_id = N'[seed:district-demo]-2010-c1-wv'
      AND ea.billed_statement_number = N'[seed:event-detail]-history'
)
BEGIN
    -- 12 days ago · $75 · PAID
    INSERT INTO dbo.event_actions (
        route_event_id, action_type, is_final, charge_amount, charge_quantity,
        payment_status, notes, billed_statement_number, created_by, date_created
    )
    SELECT id, N'charge', 0, 75.0000, 1.00, N'PAID',
           N'Overage charge applied to account.',
           N'[seed:event-detail]-history', N'Kyle.Patrick',
           DATEADD(hour, 3, DATEADD(day, -12, GETUTCDATE()))
    FROM dbo.route_events WHERE external_id = N'[seed:district-demo]-2010-c1-wv';

    -- 38 days ago · $95 · REFUNDED
    INSERT INTO dbo.event_actions (
        route_event_id, action_type, is_final, charge_amount, charge_quantity,
        payment_status, notes, billed_statement_number, created_by, date_created
    )
    SELECT id, N'charge', 0, 95.0000, 1.00, N'REFUNDED',
           N'Overage charge applied to account.',
           N'[seed:event-detail]-history', N'Kyle.Patrick',
           DATEADD(hour, 3, DATEADD(day, -38, GETUTCDATE()))
    FROM dbo.route_events WHERE external_id = N'[seed:district-demo]-2010-c1-wv';

    -- 55 days ago · $65 · PAID
    INSERT INTO dbo.event_actions (
        route_event_id, action_type, is_final, charge_amount, charge_quantity,
        payment_status, notes, billed_statement_number, created_by, date_created
    )
    SELECT id, N'charge', 0, 65.0000, 1.00, N'PAID',
           N'Overage charge applied to account.',
           N'[seed:event-detail]-history', N'Kyle.Patrick',
           DATEADD(hour, 3, DATEADD(day, -55, GETUTCDATE()))
    FROM dbo.route_events WHERE external_id = N'[seed:district-demo]-2010-c1-wv';

    -- 82 days ago · $75 · pending (NULL)
    INSERT INTO dbo.event_actions (
        route_event_id, action_type, is_final, charge_amount, charge_quantity,
        payment_status, notes, billed_statement_number, created_by, date_created
    )
    SELECT id, N'charge', 0, 75.0000, 1.00, NULL,
           N'Overage charge applied to account.',
           N'[seed:event-detail]-history', N'Kyle.Patrick',
           DATEADD(hour, 3, DATEADD(day, -82, GETUTCDATE()))
    FROM dbo.route_events WHERE external_id = N'[seed:district-demo]-2010-c1-wv';
END

GO
