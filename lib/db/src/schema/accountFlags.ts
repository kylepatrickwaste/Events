import {
  pgTable,
  serial,
  text,
  integer,
  timestamp,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { districtsTable } from "./districts";

/**
 * Account-level flags. "contract_no_overages" hides all overage events for
 * the account from the district queue and blocks future overage review.
 */
export const accountFlagsTable = pgTable(
  "account_flags",
  {
    id: serial("id").primaryKey(),
    districtId: integer("district_id")
      .notNull()
      .references(() => districtsTable.id),
    accountNumber: text("account_number").notNull(),
    flag: text("flag").notNull().default("contract_no_overages"),
    createdBy: text("created_by").notNull(),
    dateCreated: timestamp("date_created", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [
    uniqueIndex("account_flags_district_account_flag_idx").on(
      t.districtId,
      t.accountNumber,
      t.flag,
    ),
  ],
);

export type AccountFlag = typeof accountFlagsTable.$inferSelect;
