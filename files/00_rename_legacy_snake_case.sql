-- ============================================================
-- 00_rename_legacy_snake_case.sql
-- Microsoft SQL Server  —  Route Events
--
-- ONE-TIME migration for a database created before the schema
-- moved to PascalCase. Renames tables, then columns, then
-- indexes and named constraints, in place with sp_rename.
-- Rows are preserved: nothing is dropped and nothing is
-- re-seeded.
--
-- Only needed if the database still has snake_case names
-- (`route_events`, `date_occurred`). A database created by
-- 01_create_tables.sql, or already migrated by an API build up
-- to 45, needs nothing here — every statement is guarded, so
-- running it anyway is a no-op.
--
-- The guards compare names under a binary collation on purpose.
-- SQL Server object names are case-insensitive, so `districts`
-- and `Districts` are the same object and only a case-sensitive
-- check can tell whether a rename is still outstanding.
--
-- Run order:  00_rename_legacy_snake_case.sql (legacy only)
--          →  01_create_tables.sql
--          →  02_insert_mock_data.sql
--
-- Generated from the rename map that lived in the API's
-- DatabaseInitializer before schema management moved to these
-- scripts.
-- ============================================================

-- --------------------------------------------------------
-- 1.  Tables
-- --------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'districts' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'Districts' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.districts', N'Districts';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'event_types' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'EventTypes' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.event_types', N'EventTypes';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'event_sources' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'EventSources' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.event_sources', N'EventSources';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'service_codes' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'ServiceCodes' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.service_codes', N'ServiceCodes';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'route_events' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'RouteEvents' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.route_events', N'RouteEvents';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'event_actions' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'EventActions' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.event_actions', N'EventActions';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'account_flags' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'AccountFlags' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.account_flags', N'AccountFlags';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'file_imports' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'FileImports' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.file_imports', N'FileImports';
GO

IF EXISTS (SELECT 1 FROM sys.tables
           WHERE SCHEMA_NAME(schema_id) = 'dbo'
             AND name = N'event_edit_history' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.tables
                   WHERE SCHEMA_NAME(schema_id) = 'dbo'
                     AND name = N'EventEditHistory' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.event_edit_history', N'EventEditHistory';
GO

-- --------------------------------------------------------
-- 2.  Columns
--     Keyed on the PascalCase table name, which section 1 has
--     already applied.
-- --------------------------------------------------------
-- Districts
IF OBJECT_ID(N'dbo.Districts', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.Districts')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.Districts')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.Districts.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.Districts', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.Districts')
                 AND name = N'number' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.Districts')
                     AND name = N'Number' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.Districts.number', N'Number', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.Districts', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.Districts')
                 AND name = N'name' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.Districts')
                     AND name = N'Name' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.Districts.name', N'Name', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.Districts', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.Districts')
                 AND name = N'region' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.Districts')
                     AND name = N'Region' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.Districts.region', N'Region', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.Districts', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.Districts')
                 AND name = N'hauling_system' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.Districts')
                     AND name = N'HaulingSystem' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.Districts.hauling_system', N'HaulingSystem', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.Districts', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.Districts')
                 AND name = N'active' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.Districts')
                     AND name = N'Active' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.Districts.active', N'Active', 'COLUMN';
GO

-- EventTypes
IF OBJECT_ID(N'dbo.EventTypes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventTypes')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventTypes')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventTypes.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventTypes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventTypes')
                 AND name = N'name' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventTypes')
                     AND name = N'Name' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventTypes.name', N'Name', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventTypes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventTypes')
                 AND name = N'active' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventTypes')
                     AND name = N'Active' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventTypes.active', N'Active', 'COLUMN';
GO

-- EventSources
IF OBJECT_ID(N'dbo.EventSources', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventSources')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventSources')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventSources.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventSources', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventSources')
                 AND name = N'name' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventSources')
                     AND name = N'Name' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventSources.name', N'Name', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventSources', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventSources')
                 AND name = N'active' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventSources')
                     AND name = N'Active' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventSources.active', N'Active', 'COLUMN';
GO

-- ServiceCodes
IF OBJECT_ID(N'dbo.ServiceCodes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.ServiceCodes.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.ServiceCodes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                 AND name = N'district_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                     AND name = N'DistrictId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.ServiceCodes.district_id', N'DistrictId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.ServiceCodes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                 AND name = N'code' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                     AND name = N'Code' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.ServiceCodes.code', N'Code', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.ServiceCodes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                 AND name = N'description' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                     AND name = N'Description' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.ServiceCodes.description', N'Description', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.ServiceCodes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                 AND name = N'amount' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                     AND name = N'Amount' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.ServiceCodes.amount', N'Amount', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.ServiceCodes', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                 AND name = N'active' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.ServiceCodes')
                     AND name = N'Active' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.ServiceCodes.active', N'Active', 'COLUMN';
GO

-- RouteEvents
IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'district_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'DistrictId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.district_id', N'DistrictId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'event_type_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'EventTypeId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.event_type_id', N'EventTypeId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'event_source_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'EventSourceId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.event_source_id', N'EventSourceId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'external_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'ExternalId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.external_id', N'ExternalId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'date_occurred' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'DateOccurred' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.date_occurred', N'DateOccurred', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'vehicle' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Vehicle' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.vehicle', N'Vehicle', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'route' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Route' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.route', N'Route', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'latitude' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Latitude' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.latitude', N'Latitude', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'longitude' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Longitude' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.longitude', N'Longitude', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'address' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Address' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.address', N'Address', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'customer_name' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'CustomerName' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.customer_name', N'CustomerName', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'account_number' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'AccountNumber' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.account_number', N'AccountNumber', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'bill_area' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'BillArea' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.bill_area', N'BillArea', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'bin_serial_number' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'BinSerialNumber' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.bin_serial_number', N'BinSerialNumber', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'lob' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Lob' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.lob', N'Lob', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'rmo_status' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'RmoStatus' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.rmo_status', N'RmoStatus', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'details' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Details' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.details', N'Details', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'stop' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Stop' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.stop', N'Stop', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'work_order_number' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'WorkOrderNumber' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.work_order_number', N'WorkOrderNumber', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'tablet_notes' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'TabletNotes' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.tablet_notes', N'TabletNotes', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'quantity' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Quantity' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.quantity', N'Quantity', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'image_url' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'ImageUrl' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.image_url', N'ImageUrl', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'image_urls' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'ImageUrls' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.image_urls', N'ImageUrls', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'severity' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'Severity' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.severity', N'Severity', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'customer_since' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'CustomerSince' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.customer_since', N'CustomerSince', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'event_status' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'EventStatus' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.event_status', N'EventStatus', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'date_closed' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'DateClosed' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.date_closed', N'DateClosed', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'closed_by' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'ClosedBy' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.closed_by', N'ClosedBy', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'customer_routes' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'CustomerRoutes' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.customer_routes', N'CustomerRoutes', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                 AND name = N'file_import_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents')
                     AND name = N'FileImportId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.RouteEvents.file_import_id', N'FileImportId', 'COLUMN';
GO

-- EventActions
IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'route_event_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'RouteEventId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.route_event_id', N'RouteEventId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'action_type' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'ActionType' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.action_type', N'ActionType', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'is_final' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'IsFinal' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.is_final', N'IsFinal', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'notes' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'Notes' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.notes', N'Notes', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'close_reason' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'CloseReason' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.close_reason', N'CloseReason', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'service_code_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'ServiceCodeId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.service_code_id', N'ServiceCodeId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'charge_amount' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'ChargeAmount' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.charge_amount', N'ChargeAmount', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'charge_quantity' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'ChargeQuantity' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.charge_quantity', N'ChargeQuantity', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'billed_statement_number' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'BilledStatementNumber' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.billed_statement_number', N'BilledStatementNumber', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'payment_status' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'PaymentStatus' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.payment_status', N'PaymentStatus', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'billed_amount' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'BilledAmount' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.billed_amount', N'BilledAmount', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'created_by' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'CreatedBy' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.created_by', N'CreatedBy', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                 AND name = N'date_created' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions')
                     AND name = N'DateCreated' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventActions.date_created', N'DateCreated', 'COLUMN';
GO

-- AccountFlags
IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'district_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'DistrictId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.district_id', N'DistrictId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'account_number' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'AccountNumber' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.account_number', N'AccountNumber', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'flag' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'Flag' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.flag', N'Flag', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'created_by' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'CreatedBy' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.created_by', N'CreatedBy', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'date_created' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'DateCreated' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.date_created', N'DateCreated', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'name' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'Name' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.name', N'Name', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'event_type_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'EventTypeId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.event_type_id', N'EventTypeId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'event_source_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'EventSourceId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.event_source_id', N'EventSourceId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'notes' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'Notes' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.notes', N'Notes', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                 AND name = N'active' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags')
                     AND name = N'Active' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.AccountFlags.active', N'Active', 'COLUMN';
GO

-- FileImports
IF OBJECT_ID(N'dbo.FileImports', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.FileImports')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.FileImports')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.FileImports.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.FileImports', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.FileImports')
                 AND name = N'file_name' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.FileImports')
                     AND name = N'FileName' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.FileImports.file_name', N'FileName', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.FileImports', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.FileImports')
                 AND name = N'date_created' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.FileImports')
                     AND name = N'DateCreated' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.FileImports.date_created', N'DateCreated', 'COLUMN';
GO

-- EventEditHistory
IF OBJECT_ID(N'dbo.EventEditHistory', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                 AND name = N'id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                     AND name = N'Id' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventEditHistory.id', N'Id', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventEditHistory', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                 AND name = N'route_event_id' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                     AND name = N'RouteEventId' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventEditHistory.route_event_id', N'RouteEventId', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventEditHistory', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                 AND name = N'field' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                     AND name = N'Field' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventEditHistory.field', N'Field', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventEditHistory', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                 AND name = N'old_value' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                     AND name = N'OldValue' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventEditHistory.old_value', N'OldValue', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventEditHistory', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                 AND name = N'new_value' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                     AND name = N'NewValue' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventEditHistory.new_value', N'NewValue', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventEditHistory', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                 AND name = N'created_by' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                     AND name = N'CreatedBy' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventEditHistory.created_by', N'CreatedBy', 'COLUMN';
GO

IF OBJECT_ID(N'dbo.EventEditHistory', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                 AND name = N'date_created' COLLATE Latin1_General_BIN2)
   AND NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID(N'dbo.EventEditHistory')
                     AND name = N'DateCreated' COLLATE Latin1_General_BIN2)
    EXEC sp_rename N'dbo.EventEditHistory.date_created', N'DateCreated', 'COLUMN';
GO

-- --------------------------------------------------------
-- 3.  Indexes
-- --------------------------------------------------------
IF OBJECT_ID(N'dbo.RouteEvents', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.RouteEvents') AND name = N'route_events_account_date_idx')
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.RouteEvents') AND name = N'RouteEventsAccountDateIdx')
    EXEC sp_rename N'dbo.RouteEvents.route_events_account_date_idx', N'RouteEventsAccountDateIdx', 'INDEX';
GO

IF OBJECT_ID(N'dbo.EventActions', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.EventActions') AND name = N'event_actions_route_event_idx')
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.EventActions') AND name = N'EventActionsRouteEventIdx')
    EXEC sp_rename N'dbo.EventActions.event_actions_route_event_idx', N'EventActionsRouteEventIdx', 'INDEX';
GO

IF OBJECT_ID(N'dbo.AccountFlags', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.AccountFlags') AND name = N'account_flags_district_account_flag_idx')
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.AccountFlags') AND name = N'AccountFlagsDistrictAccountFlagIdx')
    EXEC sp_rename N'dbo.AccountFlags.account_flags_district_account_flag_idx', N'AccountFlagsDistrictAccountFlagIdx', 'INDEX';
GO

-- --------------------------------------------------------
-- 4.  Named constraints
--     System-generated names (PK__districts__…) are left alone.
-- --------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'pk_districts')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'PkDistricts')
    EXEC sp_rename N'dbo.pk_districts', N'PkDistricts';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_districts_active')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfDistrictsActive')
    EXEC sp_rename N'dbo.df_districts_active', N'DfDistrictsActive';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'pk_event_types')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'PkEventTypes')
    EXEC sp_rename N'dbo.pk_event_types', N'PkEventTypes';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_event_types_active')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfEventTypesActive')
    EXEC sp_rename N'dbo.df_event_types_active', N'DfEventTypesActive';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'pk_event_sources')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'PkEventSources')
    EXEC sp_rename N'dbo.pk_event_sources', N'PkEventSources';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_event_sources_active')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfEventSourcesActive')
    EXEC sp_rename N'dbo.df_event_sources_active', N'DfEventSourcesActive';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'pk_service_codes')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'PkServiceCodes')
    EXEC sp_rename N'dbo.pk_service_codes', N'PkServiceCodes';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_service_codes_active')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfServiceCodesActive')
    EXEC sp_rename N'dbo.df_service_codes_active', N'DfServiceCodesActive';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'fk_service_codes_district')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'FkServiceCodesDistrict')
    EXEC sp_rename N'dbo.fk_service_codes_district', N'FkServiceCodesDistrict';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'pk_route_events')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'PkRouteEvents')
    EXEC sp_rename N'dbo.pk_route_events', N'PkRouteEvents';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_route_events_image_urls')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfRouteEventsImageUrls')
    EXEC sp_rename N'dbo.df_route_events_image_urls', N'DfRouteEventsImageUrls';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_route_events_event_status')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfRouteEventsEventStatus')
    EXEC sp_rename N'dbo.df_route_events_event_status', N'DfRouteEventsEventStatus';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_route_events_customer_routes')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfRouteEventsCustomerRoutes')
    EXEC sp_rename N'dbo.df_route_events_customer_routes', N'DfRouteEventsCustomerRoutes';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'chk_route_events_image_urls')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'ChkRouteEventsImageUrls')
    EXEC sp_rename N'dbo.chk_route_events_image_urls', N'ChkRouteEventsImageUrls';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'chk_route_events_customer_routes')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'ChkRouteEventsCustomerRoutes')
    EXEC sp_rename N'dbo.chk_route_events_customer_routes', N'ChkRouteEventsCustomerRoutes';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'fk_route_events_district')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'FkRouteEventsDistrict')
    EXEC sp_rename N'dbo.fk_route_events_district', N'FkRouteEventsDistrict';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'fk_route_events_event_type')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'FkRouteEventsEventType')
    EXEC sp_rename N'dbo.fk_route_events_event_type', N'FkRouteEventsEventType';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'fk_route_events_event_source')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'FkRouteEventsEventSource')
    EXEC sp_rename N'dbo.fk_route_events_event_source', N'FkRouteEventsEventSource';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'pk_event_actions')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'PkEventActions')
    EXEC sp_rename N'dbo.pk_event_actions', N'PkEventActions';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_event_actions_is_final')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfEventActionsIsFinal')
    EXEC sp_rename N'dbo.df_event_actions_is_final', N'DfEventActionsIsFinal';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_event_actions_date_created')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfEventActionsDateCreated')
    EXEC sp_rename N'dbo.df_event_actions_date_created', N'DfEventActionsDateCreated';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'fk_event_actions_route_event')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'FkEventActionsRouteEvent')
    EXEC sp_rename N'dbo.fk_event_actions_route_event', N'FkEventActionsRouteEvent';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'fk_event_actions_service_code')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'FkEventActionsServiceCode')
    EXEC sp_rename N'dbo.fk_event_actions_service_code', N'FkEventActionsServiceCode';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'pk_account_flags')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'PkAccountFlags')
    EXEC sp_rename N'dbo.pk_account_flags', N'PkAccountFlags';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_account_flags_flag')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfAccountFlagsFlag')
    EXEC sp_rename N'dbo.df_account_flags_flag', N'DfAccountFlagsFlag';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'df_account_flags_date_created')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'DfAccountFlagsDateCreated')
    EXEC sp_rename N'dbo.df_account_flags_date_created', N'DfAccountFlagsDateCreated';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'fk_account_flags_district')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'FkAccountFlagsDistrict')
    EXEC sp_rename N'dbo.fk_account_flags_district', N'FkAccountFlagsDistrict';
GO

IF EXISTS (SELECT 1 FROM sys.objects
           WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'UQ_account_flags_district_account_flag')
   AND NOT EXISTS (SELECT 1 FROM sys.objects
                   WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name = N'UqAccountFlagsDistrictAccountFlag')
    EXEC sp_rename N'dbo.UQ_account_flags_district_account_flag', N'UqAccountFlagsDistrictAccountFlag';
GO

