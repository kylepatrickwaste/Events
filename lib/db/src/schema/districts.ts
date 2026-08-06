import { pgTable, serial, text, integer, boolean } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod/v4";

export const districtsTable = pgTable("districts", {
  id: serial("id").primaryKey(),
  number: text("number").notNull(),
  name: text("name").notNull(),
  region: text("region").notNull(),
  haulingSystem: integer("hauling_system"),
  active: boolean("active").notNull().default(true),
});

export const insertDistrictSchema = createInsertSchema(districtsTable).omit({
  id: true,
});
export type InsertDistrict = z.infer<typeof insertDistrictSchema>;
export type District = typeof districtsTable.$inferSelect;
