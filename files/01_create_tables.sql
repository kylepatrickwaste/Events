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
-- 1.  Districts
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.Districts', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Districts (
        Id             INT           IDENTITY(1,1) NOT NULL,
        Number         NVARCHAR(255) NOT NULL,
        Name           NVARCHAR(255) NOT NULL,
        Region         NVARCHAR(255) NOT NULL,
        HaulingSystem INT           NULL,
        Active         BIT           NOT NULL CONSTRAINT DfDistrictsActive DEFAULT 1,
        CONSTRAINT PkDistricts PRIMARY KEY (Id)
    );
END
GO

-- --------------------------------------------------------
-- 2.  EventTypes
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.EventTypes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EventTypes (
        Id     INT           IDENTITY(1,1) NOT NULL,
        Name   NVARCHAR(255) NOT NULL,
        Active BIT           NOT NULL CONSTRAINT DfEventTypesActive DEFAULT 1,
        CONSTRAINT PkEventTypes PRIMARY KEY (Id)
    );
END
GO

-- --------------------------------------------------------
-- 3.  EventSources
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.EventSources', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EventSources (
        Id     INT           IDENTITY(1,1) NOT NULL,
        Name   NVARCHAR(255) NOT NULL,
        Active BIT           NOT NULL CONSTRAINT DfEventSourcesActive DEFAULT 1,
        CONSTRAINT PkEventSources PRIMARY KEY (Id)
    );
END
GO

-- --------------------------------------------------------
-- 4.  ServiceCodes
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.ServiceCodes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ServiceCodes (
        Id          INT            IDENTITY(1,1) NOT NULL,
        DistrictId INT            NOT NULL,
        Code        NVARCHAR(255)  NOT NULL,
        Description NVARCHAR(MAX)  NOT NULL,
        Amount      DECIMAL(12, 4) NOT NULL,
        Active      BIT            NOT NULL CONSTRAINT DfServiceCodesActive DEFAULT 1,
        CONSTRAINT PkServiceCodes     PRIMARY KEY (Id),
        CONSTRAINT FkServiceCodesDistrict
            FOREIGN KEY (DistrictId) REFERENCES dbo.Districts(Id)
    );
END
GO

-- --------------------------------------------------------
-- 5.  RouteEvents
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RouteEvents (
        Id                INT            IDENTITY(1,1) NOT NULL,
        DistrictId       INT            NOT NULL,
        EventTypeId     INT            NOT NULL,
        EventSourceId   INT            NOT NULL,
        ExternalId       NVARCHAR(255)  NULL,
        DateOccurred     DATETIMEOFFSET NOT NULL,
        Vehicle           NVARCHAR(255)  NOT NULL,
        Route             NVARCHAR(255)  NOT NULL,
        Latitude          FLOAT          NOT NULL,
        Longitude         FLOAT          NOT NULL,
        Address           NVARCHAR(MAX)  NOT NULL,
        CustomerName     NVARCHAR(MAX)  NOT NULL,
        AccountNumber    NVARCHAR(255)  NOT NULL,
        BillArea         NVARCHAR(255)  NULL,
        BinSerialNumber NVARCHAR(255)  NULL,
        Lob               NVARCHAR(255)  NULL,
        RmoStatus        NVARCHAR(255)  NULL,
        Details           NVARCHAR(MAX)  NULL,
        Stop              NVARCHAR(255)  NULL,
        WorkOrderNumber NVARCHAR(255)  NULL,
        TabletNotes      NVARCHAR(MAX)  NULL,
        Quantity          DECIMAL(9, 2)  NULL,
        ImageUrl         NVARCHAR(MAX)  NULL,
        -- JSON array of additional photo URLs; imageUrl is the primary photo
        ImageUrls        NVARCHAR(MAX)  NOT NULL
            CONSTRAINT DfRouteEventsImageUrls    DEFAULT N'[]'
            CONSTRAINT ChkRouteEventsImageUrls   CHECK  (ISJSON(ImageUrls) = 1),
        Severity          NVARCHAR(255)  NULL,
        CustomerSince    DATETIMEOFFSET NULL,
        -- 0 = open, 1 = closed
        EventStatus      INT            NOT NULL CONSTRAINT DfRouteEventsEventStatus DEFAULT 0,
        DateClosed       DATETIMEOFFSET NULL,
        ClosedBy         NVARCHAR(255)  NULL,
        -- JSON array of CustomerRouteJson objects
        CustomerRoutes   NVARCHAR(MAX)  NOT NULL
            CONSTRAINT DfRouteEventsCustomerRoutes  DEFAULT N'[]'
            CONSTRAINT ChkRouteEventsCustomerRoutes CHECK  (ISJSON(CustomerRoutes) = 1),
        CONSTRAINT PkRouteEvents PRIMARY KEY (Id),
        CONSTRAINT FkRouteEventsDistrict
            FOREIGN KEY (DistrictId)     REFERENCES dbo.Districts(Id),
        CONSTRAINT FkRouteEventsEventType
            FOREIGN KEY (EventTypeId)   REFERENCES dbo.EventTypes(Id),
        CONSTRAINT FkRouteEventsEventSource
            FOREIGN KEY (EventSourceId) REFERENCES dbo.EventSources(Id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE Name = N'RouteEventsAccountDateIdx'
      AND object_id = OBJECT_ID(N'dbo.RouteEvents')
)
BEGIN
    CREATE INDEX RouteEventsAccountDateIdx
        ON dbo.RouteEvents (AccountNumber, DateOccurred);
END
GO

-- --------------------------------------------------------
-- 6.  EventActions
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.EventActions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EventActions (
        Id                      INT            IDENTITY(1,1) NOT NULL,
        RouteEventId          INT            NOT NULL,
        ActionType             NVARCHAR(255)  NOT NULL,
        IsFinal                BIT            NOT NULL CONSTRAINT DfEventActionsIsFinal DEFAULT 0,
        Notes                   NVARCHAR(MAX)  NULL,
        CloseReason            NVARCHAR(MAX)  NULL,
        ServiceCodeId         INT            NULL,
        ChargeAmount           DECIMAL(12, 4) NULL,
        ChargeQuantity         DECIMAL(9, 2)  NULL,
        BilledStatementNumber NVARCHAR(255)  NULL,
        PaymentStatus          NVARCHAR(255)  NULL,
        BilledAmount           DECIMAL(12, 4) NULL,
        CreatedBy              NVARCHAR(255)  NOT NULL,
        DateCreated            DATETIMEOFFSET NOT NULL
            CONSTRAINT DfEventActionsDateCreated DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT PkEventActions PRIMARY KEY (Id),
        CONSTRAINT FkEventActionsRouteEvent
            FOREIGN KEY (RouteEventId)  REFERENCES dbo.RouteEvents(Id),
        CONSTRAINT FkEventActionsServiceCode
            FOREIGN KEY (ServiceCodeId) REFERENCES dbo.ServiceCodes(Id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE Name = N'EventActionsRouteEventIdx'
      AND object_id = OBJECT_ID(N'dbo.EventActions')
)
BEGIN
    CREATE INDEX EventActionsRouteEventIdx
        ON dbo.EventActions (RouteEventId);
END
GO

-- --------------------------------------------------------
-- 7.  AccountFlags
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AccountFlags (
        Id             INT            IDENTITY(1,1) NOT NULL,
        DistrictId    INT            NOT NULL,
        AccountNumber NVARCHAR(255)  NOT NULL,
        Flag           NVARCHAR(255)  NOT NULL CONSTRAINT DfAccountFlagsFlag DEFAULT N'contract_no_overages',
        CreatedBy     NVARCHAR(255)  NOT NULL,
        DateCreated   DATETIMEOFFSET NOT NULL
            CONSTRAINT DfAccountFlagsDateCreated DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT PkAccountFlags PRIMARY KEY (Id),
        CONSTRAINT FkAccountFlagsDistrict
            FOREIGN KEY (DistrictId) REFERENCES dbo.Districts(Id)
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE Name = N'AccountFlagsDistrictAccountFlagIdx'
      AND object_id = OBJECT_ID(N'dbo.AccountFlags')
)
BEGIN
    CREATE UNIQUE INDEX AccountFlagsDistrictAccountFlagIdx
        ON dbo.AccountFlags (DistrictId, AccountNumber, Flag);
END
GO
