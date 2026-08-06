import {
  pgTable,
  serial,
  text,
  integer,
  boolean,
  numeric,
} from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";
import { districtsTable } from "./districts";

export const eventTypesTable = pgTable("event_types", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  active: boolean("active").notNull().default(true),
});

export const eventSourcesTable = pgTable("event_sources", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  active: boolean("active").notNull().default(true),
});

export const serviceCodesTable = pgTable("service_codes", {
  id: serial("id").primaryKey(),
  districtId: integer("district_id")
    .notNull()
    .references(() => districtsTable.id),
  code: text("code").notNull(),
  description: text("description").notNull(),
  amount: numeric("amount", { precision: 12, scale: 4 }).notNull(),
  active: boolean("active").notNull().default(true),
});

export const insertEventTypeSchema = createInsertSchema(eventTypesTable).omit({
  id: true,
});
export type EventType = typeof eventTypesTable.$inferSelect;
export const insertEventSourceSchema = createInsertSchema(
  eventSourcesTable,
).omit({ id: true });
export type EventSource = typeof eventSourcesTable.$inferSelect;
export const insertServiceCodeSchema = createInsertSchema(
  serviceCodesTable,
).omit({ id: true });
export type ServiceCode = typeof serviceCodesTable.$inferSelect;
export type InsertServiceCode = z.infer<typeof insertServiceCodeSchema>;
