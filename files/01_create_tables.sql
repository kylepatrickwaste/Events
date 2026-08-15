-- ============================================================
-- 01_create_tables.sql
-- Microsoft SQL Server  —  Route Events schema
--
-- Creates all seven application tables with correct MSSQL types,
-- primary keys, foreign keys, indexes, and CHECK constraints.
--
-- Idempotent: each CREATE TABLE and CREATE INDEX block is guarded
-- with IF OBJECT_ID / IF NOT EXISTS so the script can be re-run
-- on an already-initialised database without error.
--
-- Run order:  01_create_tables.sql  →  02_insert_mock_data.sql
-- ============================================================

-- --------------------------------------------------------
-- 1.  districts
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.districts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.districts (
        id             INT           IDENTITY(1,1) NOT NULL,
        number         NVARCHAR(255) NOT NULL,
        name           NVARCHAR(255) NOT NULL,
        region         NVARCHAR(255) NOT NULL,
        hauling_system INT           NULL,
        active         BIT           NOT NULL CONSTRAINT df_districts_active DEFAULT 1,
        CONSTRAINT pk_districts PRIMARY KEY (id)
    );
END
GO

-- --------------------------------------------------------
-- 2.  event_types
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.event_types', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.event_types (
        id     INT           IDENTITY(1,1) NOT NULL,
        name   NVARCHAR(255) NOT NULL,
        active BIT           NOT NULL CONSTRAINT df_event_types_active DEFAULT 1,
        CONSTRAINT pk_event_types PRIMARY KEY (id)
    );
END
GO

-- --------------------------------------------------------
-- 3.  event_sources
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.event_sources', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.event_sources (
        id     INT           IDENTITY(1,1) NOT NULL,
        name   NVARCHAR(255) NOT NULL,
        active BIT           NOT NULL CONSTRAINT df_event_sources_active DEFAULT 1,
        CONSTRAINT pk_event_sources PRIMARY KEY (id)
    );
END
GO

-- --------------------------------------------------------
-- 4.  service_codes
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.service_codes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.service_codes (
        id          INT            IDENTITY(1,1) NOT NULL,
        district_id INT            NOT NULL,
        code        NVARCHAR(255)  NOT NULL,
        description NVARCHAR(MAX)  NOT NULL,
        amount      DECIMAL(12, 4) NOT NULL,
        active      BIT            NOT NULL CONSTRAINT df_service_codes_active DEFAULT 1,
        CONSTRAINT pk_service_codes     PRIMARY KEY (id),
        CONSTRAINT fk_service_codes_district
            FOREIGN KEY (district_id) REFERENCES dbo.districts(id)
    );
END
GO

-- --------------------------------------------------------
-- 5.  route_events
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.route_events', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.route_events (
        id                INT            IDENTITY(1,1) NOT NULL,
        district_id       INT            NOT NULL,
        event_type_id     INT            NOT NULL,
        event_source_id   INT            NOT NULL,
        external_id       NVARCHAR(255)  NULL,
        date_occurred     DATETIMEOFFSET NOT NULL,
        vehicle           NVARCHAR(255)  NOT NULL,
        route             NVARCHAR(255)  NOT NULL,
        latitude          FLOAT          NOT NULL,
        longitude         FLOAT          NOT NULL,
        address           NVARCHAR(MAX)  NOT NULL,
        customer_name     NVARCHAR(MAX)  NOT NULL,
        account_number    NVARCHAR(255)  NOT NULL,
        bill_area         NVARCHAR(255)  NULL,
        bin_serial_number NVARCHAR(255)  NULL,
        lob               NVARCHAR(255)  NULL,
        rmo_status        NVARCHAR(255)  NULL,
        details           NVARCHAR(MAX)  NULL,
        stop              NVARCHAR(255)  NULL,
        work_order_number NVARCHAR(255)  NULL,
        tablet_notes      NVARCHAR(MAX)  NULL,
        quantity          DECIMAL(9, 2)  NULL,
        image_url         NVARCHAR(MAX)  NULL,
        -- JSON array of additional photo URLs; imageUrl is the primary photo
        image_urls        NVARCHAR(MAX)  NOT NULL
            CONSTRAINT df_route_events_image_urls    DEFAULT N'[]'
            CONSTRAINT chk_route_events_image_urls   CHECK  (ISJSON(image_urls) = 1),
        severity          NVARCHAR(255)  NULL,
        customer_since    DATETIMEOFFSET NULL,
        -- 0 = open, 1 = closed
        event_status      INT            NOT NULL CONSTRAINT df_route_events_event_status DEFAULT 0,
        date_closed       DATETIMEOFFSET NULL,
        closed_by         NVARCHAR(255)  NULL,
        -- JSON array of CustomerRouteJson objects
        customer_routes   NVARCHAR(MAX)  NOT NULL
            CONSTRAINT df_route_events_customer_routes  DEFAULT N'[]'
            CONSTRAINT chk_route_events_customer_routes CHECK  (ISJSON(customer_routes) = 1),
        CONSTRAINT pk_route_events PRIMARY KEY (id),
        CONSTRAINT fk_route_events_district
            FOREIGN KEY (district_id)     REFERENCES dbo.districts(id),
        CONSTRAINT fk_route_events_event_type
            FOREIGN KEY (event_type_id)   REFERENCES dbo.event_types(id),
        CONSTRAINT fk_route_events_event_source
            FOREIGN KEY (event_source_id) REFERENCES dbo.event_sources(id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'route_events_account_date_idx'
      AND object_id = OBJECT_ID(N'dbo.route_events')
)
BEGIN
    CREATE INDEX route_events_account_date_idx
        ON dbo.route_events (account_number, date_occurred);
END
GO

-- --------------------------------------------------------
-- 6.  event_actions
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.event_actions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.event_actions (
        id                      INT            IDENTITY(1,1) NOT NULL,
        route_event_id          INT            NOT NULL,
        action_type             NVARCHAR(255)  NOT NULL,
        is_final                BIT            NOT NULL CONSTRAINT df_event_actions_is_final DEFAULT 0,
        notes                   NVARCHAR(MAX)  NULL,
        close_reason            NVARCHAR(MAX)  NULL,
        service_code_id         INT            NULL,
        charge_amount           DECIMAL(12, 4) NULL,
        charge_quantity         DECIMAL(9, 2)  NULL,
        billed_statement_number NVARCHAR(255)  NULL,
        payment_status          NVARCHAR(255)  NULL,
        billed_amount           DECIMAL(12, 4) NULL,
        created_by              NVARCHAR(255)  NOT NULL,
        date_created            DATETIMEOFFSET NOT NULL
            CONSTRAINT df_event_actions_date_created DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT pk_event_actions PRIMARY KEY (id),
        CONSTRAINT fk_event_actions_route_event
            FOREIGN KEY (route_event_id)  REFERENCES dbo.route_events(id),
        CONSTRAINT fk_event_actions_service_code
            FOREIGN KEY (service_code_id) REFERENCES dbo.service_codes(id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'event_actions_route_event_idx'
      AND object_id = OBJECT_ID(N'dbo.event_actions')
)
BEGIN
    CREATE INDEX event_actions_route_event_idx
        ON dbo.event_actions (route_event_id);
END
GO

-- --------------------------------------------------------
-- 7.  account_flags
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.account_flags', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.account_flags (
        id             INT            IDENTITY(1,1) NOT NULL,
        district_id    INT            NOT NULL,
        account_number NVARCHAR(255)  NOT NULL,
        flag           NVARCHAR(255)  NOT NULL CONSTRAINT df_account_flags_flag DEFAULT N'contract_no_overages',
        created_by     NVARCHAR(255)  NOT NULL,
        date_created   DATETIMEOFFSET NOT NULL
            CONSTRAINT df_account_flags_date_created DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT pk_account_flags PRIMARY KEY (id),
        CONSTRAINT fk_account_flags_district
            FOREIGN KEY (district_id) REFERENCES dbo.districts(id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'account_flags_district_account_flag_idx'
      AND object_id = OBJECT_ID(N'dbo.account_flags')
)
BEGIN
    CREATE UNIQUE INDEX account_flags_district_account_flag_idx
        ON dbo.account_flags (district_id, account_number, flag);
END
GO
