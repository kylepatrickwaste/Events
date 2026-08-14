import {
  pgTable,
  serial,
  text,
  integer,
  boolean,
  numeric,
  doublePrecision,
  timestamp,
  jsonb,
  index,
} from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";
import { districtsTable } from "./districts";
import { eventTypesTable, eventSourcesTable, serviceCodesTable } from "./lookups";

export type CustomerRouteJson = {
  code: string;
  service: string;
  material: string;
  day: string;
};

export const routeEventsTable = pgTable("route_events", {
  id: serial("id").primaryKey(),
  districtId: integer("district_id")
    .notNull()
    .references(() => districtsTable.id),
  eventTypeId: integer("event_type_id")
    .notNull()
    .references(() => eventTypesTable.id),
  eventSourceId: integer("event_source_id")
    .notNull()
    .references(() => eventSourcesTable.id),
  externalId: text("external_id"),
  dateOccurred: timestamp("date_occurred", { withTimezone: true }).notNull(),
  vehicle: text("vehicle").notNull(),
  route: text("route").notNull(),
  latitude: doublePrecision("latitude").notNull(),
  longitude: doublePrecision("longitude").notNull(),
  address: text("address").notNull(),
  customerName: text("customer_name").notNull(),
  accountNumber: text("account_number").notNull(),
  billArea: text("bill_area"),
  binSerialNumber: text("bin_serial_number"),
  lob: text("lob"),
  rmoStatus: text("rmo_status"),
  details: text("details"),
  stop: text("stop"),
  workOrderNumber: text("work_order_number"),
  tabletNotes: text("tablet_notes"),
  quantity: numeric("quantity", { precision: 9, scale: 2 }),
  imageUrl: text("image_url"),
  // additional photos of the event; imageUrl remains the primary/original image
  imageUrls: jsonb("image_urls").$type<string[]>().notNull().default([]),
  // "Severe" | "Minimal"
  severity: text("severity"),
  customerSince: timestamp("customer_since", { withTimezone: true }),
  // 0 = open, 1 = closed
  eventStatus: integer("event_status").notNull().default(0),
  dateClosed: timestamp("date_closed", { withTimezone: true }),
  closedBy: text("closed_by"),
  customerRoutes: jsonb("customer_routes")
    .$type<CustomerRouteJson[]>()
    .notNull()
    .default([]),
}, (t) => [
  index("route_events_account_date_idx").on(t.accountNumber, t.dateOccurred),
]);

export const eventActionsTable = pgTable("event_actions", {
  id: serial("id").primaryKey(),
  routeEventId: integer("route_event_id")
    .notNull()
    .references(() => routeEventsTable.id),
  actionType: text("action_type").notNull(),
  isFinal: boolean("is_final").notNull().default(false),
  notes: text("notes"),
  closeReason: text("close_reason"),
  serviceCodeId: integer("service_code_id").references(
    () => serviceCodesTable.id,
  ),
  chargeAmount: numeric("charge_amount", { precision: 12, scale: 4 }),
  chargeQuantity: numeric("charge_quantity", { precision: 9, scale: 2 }),
  billedStatementNumber: text("billed_statement_number"),
  // "PAID" | "REFUNDED" | null (pending) — for charge actions
  paymentStatus: text("payment_status"),
  billedAmount: numeric("billed_amount", { precision: 12, scale: 4 }),
  createdBy: text("created_by").notNull(),
  dateCreated: timestamp("date_created", { withTimezone: true })
    .notNull()
    .defaultNow(),
}, (t) => [
  index("event_actions_route_event_idx").on(t.routeEventId),
]);

export const insertRouteEventSchema = createInsertSchema(
  routeEventsTable,
).omit({ id: true });
export type InsertRouteEvent = z.infer<typeof insertRouteEventSchema>;
export type RouteEvent = typeof routeEventsTable.$inferSelect;

export const insertEventActionSchema = createInsertSchema(
  eventActionsTable,
).omit({ id: true, dateCreated: true });
export type InsertEventAction = z.infer<typeof insertEventActionSchema>;
export type EventAction = typeof eventActionsTable.$inferSelect;
