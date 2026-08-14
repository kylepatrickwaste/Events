/**
 * Repeatable data seed: point route_events image URLs at the real
 * truck-camera photos served from the events web artifact at
 * /event-photos/truck-cam-1.jpg … truck-cam-7.jpg.
 *
 * Distribution keeps variety: some events have multiple photos,
 * some have exactly one, and some have none.
 *
 * Idempotent — safe to re-run. Also cleans up any rows still pointing at
 * the retired ev1.jpg–ev4.jpg placeholders (those files no longer exist).
 *
 * Run with: pnpm --filter @workspace/db run seed:event-photos
 */
import { sql, asc } from "drizzle-orm";
import { db, pool } from "../index";
import { routeEventsTable as routeEvents } from "../schema";

const photo = (n: number) => `/event-photos/truck-cam-${n}.jpg`;

/** main photo (null = no photo) + extra photos, cycled over events by index */
const PATTERN: Array<{ main: number | null; extra: number[] }> = [
  { main: 1, extra: [2, 3] },
  { main: 4, extra: [] },
  { main: 5, extra: [6, 7] },
  { main: 2, extra: [] },
  { main: null, extra: [] },
  { main: 3, extra: [] },
  { main: 6, extra: [1] },
  { main: null, extra: [] },
  { main: 7, extra: [4] },
  { main: 5, extra: [] },
  { main: null, extra: [] },
  { main: 1, extra: [] },
  { main: 7, extra: [2, 5] },
];

async function main() {
  const events = await db
    .select({ id: routeEvents.id })
    .from(routeEvents)
    .orderBy(asc(routeEvents.id));

  for (let i = 0; i < events.length; i++) {
    const { main: m, extra } = PATTERN[i % PATTERN.length]!;
    await db
      .update(routeEvents)
      .set({
        imageUrl: m === null ? null : photo(m),
        imageUrls: extra.map(photo),
      })
      .where(sql`${routeEvents.id} = ${events[i]!.id}`);
  }

  const [stale] = await db
    .select({ count: sql<number>`count(*)` })
    .from(routeEvents)
    .where(
      sql`${routeEvents.imageUrl} LIKE '%/ev_.jpg' OR ${routeEvents.imageUrls}::text LIKE '%/ev_.jpg%'`,
    );
  console.log(
    `Seeded photos for ${events.length} events; rows still referencing retired ev*.jpg: ${stale?.count ?? 0}`,
  );
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
