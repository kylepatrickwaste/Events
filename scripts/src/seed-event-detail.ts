/**
 * Seeds sample data for the event detail page enhancements:
 * severity, multiple images, customer tenure,
 * nearby overages, and charge/payment history.
 *
 * Idempotent: safe to run multiple times.
 */
import { db, routeEventsTable, eventActionsTable } from "@workspace/db";
import { eq, and, like, inArray } from "drizzle-orm";

const PHOTOS = [
  "/event-photos/truck-cam-1.jpg",
  "/event-photos/truck-cam-2.jpg",
  "/event-photos/truck-cam-3.jpg",
  "/event-photos/truck-cam-4.jpg",
  "/event-photos/truck-cam-5.jpg",
  "/event-photos/truck-cam-6.jpg",
  "/event-photos/truck-cam-7.jpg",
];

const SEED_TAG = "[seed:event-detail]";

function monthsAgo(months: number): Date {
  const d = new Date();
  d.setMonth(d.getMonth() - months);
  return d;
}

function daysAgo(days: number, hoursOffset = 0): Date {
  return new Date(Date.now() - days * 86400000 + hoursOffset * 3600000);
}

async function main() {
  const events = await db.select().from(routeEventsTable);
  if (events.length === 0) {
    console.log("No events in the database; nothing to seed.");
    return;
  }

  // 1. Give every event severity, extra images, and tenure.
  const severities = ["Severe", "Minimal"];
  for (const [i, e] of events.entries()) {
    const primary = e.imageUrl ?? PHOTOS[0]!;
    const extras = PHOTOS.filter((p) => p !== primary);
    await db
      .update(routeEventsTable)
      .set({
        severity: e.severity ?? severities[i % 2]!,
        imageUrls: e.imageUrls.length > 0 ? e.imageUrls : [primary, ...extras],
        customerSince: e.customerSince ?? monthsAgo(7 + i * 9),
      })
      .where(eq(routeEventsTable.id, e.id));
  }

  // Deterministic anchor: lowest-id open, non-seeded event (fallback: lowest id).
  const candidates = events
    .filter((e) => !e.externalId?.startsWith(SEED_TAG))
    .sort((a, b) => a.id - b.id);
  const main =
    candidates.find((e) => e.eventStatus === 0) ?? candidates[0] ?? events[0]!;

  // 2. Nearby overages around the main event (same district, close in time & location).
  // Upserted per-spec by externalId so re-runs never duplicate rows and
  // existing seeded rows pick up newer field values.
  const existingNearby = await db
    .select()
    .from(routeEventsTable)
    .where(like(routeEventsTable.externalId, `${SEED_TAG}%`));
  const existingByExternalId = new Map(
    existingNearby.map((r) => [r.externalId, r]),
  );

  {
    // Remove stale untagged demo leftovers from earlier seed versions so
    // re-running converges on exactly the tagged cluster below.
    const staleLeftovers = await db
      .select({ id: routeEventsTable.id })
      .from(routeEventsTable)
      .where(like(routeEventsTable.externalId, "WV-9031%"));
    const staleIds = staleLeftovers
      .map((r) => r.id)
      .filter((id) => id !== main.id);
    if (staleIds.length > 0) {
      await db
        .delete(eventActionsTable)
        .where(inArray(eventActionsTable.routeEventId, staleIds));
      await db
        .delete(routeEventsTable)
        .where(inArray(routeEventsTable.id, staleIds));
      console.log("Removed stale demo leftovers:", staleIds.join(", "));
    }

    // Remove obsolete *tagged* nearby rows from earlier seed versions whose
    // suffixes are no longer in the desired set (e.g. the old "-nearby-D").
    const desiredExternalIds = new Set(
      ["A", "B", "C", "X"].map((s) => `${SEED_TAG}-nearby-${s}`),
    );
    const obsoleteTaggedIds = existingNearby
      .filter((r) => r.externalId && !desiredExternalIds.has(r.externalId))
      .map((r) => r.id);
    if (obsoleteTaggedIds.length > 0) {
      await db
        .delete(eventActionsTable)
        .where(inArray(eventActionsTable.routeEventId, obsoleteTaggedIds));
      await db
        .delete(routeEventsTable)
        .where(inArray(routeEventsTable.id, obsoleteTaggedIds));
      console.log(
        "Removed obsolete tagged nearby rows:",
        obsoleteTaggedIds.join(", "),
      );
    }

    // Offsets at ~30°N: 1e-4 deg lat ≈ 11.1 m, 1e-4 deg lng ≈ 9.6 m.
    // A: ~110 m Open, B: ~175 m Charged, C: ~288 m Dismissed (just inside
    // the 300 m radius), X: ~335 m Open (just OUTSIDE — must not appear).
    const nearbySpecs = [
      {
        offsetSec: -540, dLat: 0.0009, dLng: -0.0005, img: PHOTOS[1]!, status: 0, charged: false, suffix: "A",
        customerName: "Cascade Coffee Roasters", accountNumber: "7-41255-33002", binSerialNumber: "BIN-88213",
      },
      {
        offsetSec: 320, dLat: -0.0014, dLng: 0.0008, img: PHOTOS[2]!, status: 1, charged: true, suffix: "B",
        customerName: "Harborview Deli & Market", accountNumber: "7-58990-11407", binSerialNumber: "BIN-90441",
      },
      {
        offsetSec: 1150, dLat: 0.002, dLng: 0.0019, img: PHOTOS[3]!, status: 1, charged: false, suffix: "C",
        customerName: main.customerName, accountNumber: main.accountNumber, binSerialNumber: main.binSerialNumber,
      },
      {
        offsetSec: 600, dLat: 0.0024, dLng: 0.0021, img: PHOTOS[4]!, status: 0, charged: false, suffix: "X",
        customerName: "Pinecrest Auto Body", accountNumber: "7-33208-55910", binSerialNumber: "BIN-77120",
      },
    ];
    for (const s of nearbySpecs) {
      const externalId = `${SEED_TAG}-nearby-${s.suffix}`;
      const existing = existingByExternalId.get(externalId);
      if (existing) {
        await db
          .update(routeEventsTable)
          .set({
            vehicle: main.vehicle,
            route: main.route,
            dateOccurred: new Date(
              main.dateOccurred.getTime() + s.offsetSec * 1000,
            ),
            latitude: main.latitude + s.dLat,
            longitude: main.longitude + s.dLng,
            eventStatus: s.status,
            dateClosed: s.status === 1 ? (existing.dateClosed ?? daysAgo(1)) : null,
            closedBy: s.status === 1 ? (existing.closedBy ?? "Kyle.Patrick") : null,
            customerName: s.customerName,
            accountNumber: s.accountNumber,
            binSerialNumber: s.binSerialNumber,
          })
          .where(eq(routeEventsTable.id, existing.id));
        continue;
      }
      const [inserted] = await db
        .insert(routeEventsTable)
        .values({
          districtId: main.districtId,
          eventTypeId: main.eventTypeId,
          eventSourceId: main.eventSourceId,
          externalId: `${SEED_TAG}-nearby-${s.suffix}`,
          dateOccurred: new Date(main.dateOccurred.getTime() + s.offsetSec * 1000),
          vehicle: main.vehicle,
          route: main.route,
          latitude: main.latitude + s.dLat,
          longitude: main.longitude + s.dLng,
          address: main.address,
          customerName: s.customerName,
          accountNumber: s.accountNumber,
          binSerialNumber: s.binSerialNumber,
          lob: main.lob,
          imageUrl: s.img,
          imageUrls: [s.img],
          severity: "Minimal",
          customerSince: main.customerSince ?? monthsAgo(16),
          eventStatus: s.status,
          dateClosed: s.status === 1 ? daysAgo(1) : null,
          closedBy: s.status === 1 ? "Kyle.Patrick" : null,
          customerRoutes: main.customerRoutes,
        })
        .returning();
      if (s.status === 1) {
        await db.insert(eventActionsTable).values({
          routeEventId: inserted!.id,
          actionType: s.charged ? "charge" : "close",
          isFinal: true,
          closeReason: s.charged ? null : "Not an Overfill",
          serviceCodeId: null,
          chargeAmount: s.charged ? "65.0000" : null,
          chargeQuantity: s.charged ? "1.00" : null,
          paymentStatus: s.charged ? "PAID" : null,
          billedStatementNumber: SEED_TAG,
          createdBy: "Kyle.Patrick",
        });
      }
    }
    console.log("Upserted nearby overages for event", main.id);
  }

  // 3. Charge/payment history for the main event's account (last 30/60/90 days).
  const existingHistory = await db
    .select()
    .from(eventActionsTable)
    .where(
      and(
        eq(eventActionsTable.routeEventId, main.id),
        eq(eventActionsTable.billedStatementNumber, `${SEED_TAG}-history`),
      ),
    );

  if (existingHistory.length === 0) {
    const history = [
      { days: 12, amount: "75.0000", paymentStatus: "PAID" },
      { days: 38, amount: "95.0000", paymentStatus: "REFUNDED" },
      { days: 55, amount: "65.0000", paymentStatus: "PAID" },
      { days: 82, amount: "75.0000", paymentStatus: null },
    ];
    for (const h of history) {
      await db.insert(eventActionsTable).values({
        routeEventId: main.id,
        actionType: "charge",
        isFinal: false,
        chargeAmount: h.amount,
        chargeQuantity: "1.00",
        paymentStatus: h.paymentStatus,
        notes: "Overage charge applied to account.",
        billedStatementNumber: `${SEED_TAG}-history`,
        createdBy: "Kyle.Patrick",
        dateCreated: daysAgo(h.days, 3),
      });
    }
    console.log("Inserted charge history for account", main.accountNumber);
  } else {
    console.log("Charge history already seeded, skipping.");
  }

  // 4. Mark any pre-existing charges without payment status as paid.
  const unpaid = await db
    .select()
    .from(eventActionsTable)
    .where(eq(eventActionsTable.actionType, "charge"));
  for (const a of unpaid) {
    if (a.paymentStatus === null && !a.billedStatementNumber?.startsWith(SEED_TAG)) {
      await db
        .update(eventActionsTable)
        .set({ paymentStatus: "PAID" })
        .where(eq(eventActionsTable.id, a.id));
    }
  }

  console.log("Seed complete.");
}

main().then(() => process.exit(0));
