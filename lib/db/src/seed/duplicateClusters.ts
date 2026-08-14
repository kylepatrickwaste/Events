/**
 * Repeatable data seed: open event clusters that look like the same physical
 * overage reported by two camera vendors (WasteVision + 3rd Eye) minutes
 * apart, so the "Likely duplicate" pre-checked suggestions in the charge/close
 * flows have data to show.
 *
 * Clusters are pairs/triples in the same district at nearly the same lat/lng
 * (within ~20-50 m) and 2-3 minutes apart — well inside the API's suggestion
 * thresholds (<=75 m and <=5 min).
 *
 * Idempotent — rows are keyed by an externalId prefixed "DUPSEED-"; existing
 * rows with those ids are refreshed (re-opened, dates re-anchored) rather
 * than duplicated.
 *
 * Run with: pnpm --filter @workspace/db run seed:duplicate-clusters
 */
import { eq } from "drizzle-orm";
import { db, pool } from "../index";
import { routeEventsTable, type InsertRouteEvent } from "../schema";

// Event sources (lookup ids): 1 = WasteVision, 2 = 3rd Eye
const WASTEVISION = 1;
const THIRD_EYE = 2;

// Anchor "now" so clusters are always recent relative to seeding time:
// spread over the last couple of days during working hours.
const now = new Date();
function at(daysAgo: number, hour: number, minute: number): Date {
  const d = new Date(now);
  d.setDate(d.getDate() - daysAgo);
  d.setHours(hour, minute, 0, 0);
  return d;
}

type ClusterMember = {
  externalId: string; // unique, DUPSEED- prefix
  eventSourceId: number;
  latOffset: number; // degrees (~0.0002 ≈ 22 m)
  lngOffset: number;
  minuteOffset: number; // minutes after the cluster anchor time
  vehicle: string;
  imageUrl: string | null;
};

type Cluster = {
  districtId: number;
  eventTypeId: number;
  base: {
    lat: number;
    lng: number;
    address: string;
    customerName: string;
    accountNumber: string;
    route: string;
    severity: "Severe" | "Minimal";
    quantity: string | null;
    when: Date;
  };
  members: ClusterMember[];
};

const photo = (n: number) => `/event-photos/truck-cam-${n}.jpg`;

const CLUSTERS: Cluster[] = [
  // --- District 1 (VANCOUVER, WA) — pair: WasteVision + 3rd Eye, 2 min apart, ~25 m
  {
    districtId: 1,
    eventTypeId: 1, // Extra
    base: {
      lat: 45.6339,
      lng: -122.6031,
      address: "11505 NE FOURTH PLAIN BLVD, VANCOUVER, WA",
      customerName: "ORCHARDS MARKET CENTER",
      accountNumber: "2010-4451220",
      route: "VA204",
      severity: "Severe",
      quantity: "1.00",
      when: at(0, 8, 12),
    },
    members: [
      {
        externalId: "DUPSEED-2010-A1",
        eventSourceId: WASTEVISION,
        latOffset: 0,
        lngOffset: 0,
        minuteOffset: 0,
        vehicle: "2010-118 FEL",
        imageUrl: photo(1),
      },
      {
        externalId: "DUPSEED-2010-A2",
        eventSourceId: THIRD_EYE,
        latOffset: 0.0002,
        lngOffset: -0.0001,
        minuteOffset: 2,
        vehicle: "2010-121 REL",
        imageUrl: photo(3),
      },
    ],
  },
  // --- District 1 (VANCOUVER, WA) — second pair: Overloaded, 3 min apart, ~40 m
  {
    districtId: 1,
    eventTypeId: 3, // Overloaded
    base: {
      lat: 45.6205,
      lng: -122.6721,
      address: "1015 COLUMBIA ST, VANCOUVER, WA",
      customerName: "WATERFRONT COMMONS HOA",
      accountNumber: "2010-4462818",
      route: "VR310",
      severity: "Minimal",
      quantity: "1.00",
      when: at(1, 10, 41),
    },
    members: [
      {
        externalId: "DUPSEED-2010-B1",
        eventSourceId: THIRD_EYE,
        latOffset: 0,
        lngOffset: 0,
        minuteOffset: 0,
        vehicle: "2010-121 REL",
        imageUrl: photo(5),
      },
      {
        externalId: "DUPSEED-2010-B2",
        eventSourceId: WASTEVISION,
        latOffset: -0.0003,
        lngOffset: 0.0002,
        minuteOffset: 3,
        vehicle: "2010-118 FEL",
        imageUrl: photo(6),
      },
    ],
  },
  // --- District 3 (CASCADE DISPOSAL — Bend, OR) — pair, 2 min apart, ~30 m
  {
    districtId: 3,
    eventTypeId: 1, // Extra
    base: {
      lat: 44.0582,
      lng: -121.3011,
      address: "61249 S HWY 97, BEND, OR",
      customerName: "PONDEROSA PLAZA",
      accountNumber: "2012-5530417",
      route: "BD102",
      severity: "Severe",
      quantity: "2.00",
      when: at(0, 9, 27),
    },
    members: [
      {
        externalId: "DUPSEED-2012-A1",
        eventSourceId: WASTEVISION,
        latOffset: 0,
        lngOffset: 0,
        minuteOffset: 0,
        vehicle: "2012-207 FEL",
        imageUrl: photo(2),
      },
      {
        externalId: "DUPSEED-2012-A2",
        eventSourceId: THIRD_EYE,
        latOffset: 0.00025,
        lngOffset: 0.0002,
        minuteOffset: 2,
        vehicle: "2012-211 FEL",
        imageUrl: photo(4),
      },
    ],
  },
  // --- District 20 (Houston, TX) — triple: WV + 3rd Eye + WV, within 3 min / ~45 m
  {
    districtId: 20,
    eventTypeId: 3, // Overloaded
    base: {
      lat: 29.7433,
      lng: -95.3921,
      address: "3800 SOUTHWEST FWY, HOUSTON, TX",
      customerName: "GREENWAY COMMONS",
      accountNumber: "5120-7791340",
      route: "NY605",
      severity: "Severe",
      quantity: "1.00",
      when: at(0, 7, 58),
    },
    members: [
      {
        externalId: "DUPSEED-5120-A1",
        eventSourceId: WASTEVISION,
        latOffset: 0,
        lngOffset: 0,
        minuteOffset: 0,
        vehicle: "5120-2302 FEL",
        imageUrl: photo(7),
      },
      {
        externalId: "DUPSEED-5120-A2",
        eventSourceId: THIRD_EYE,
        latOffset: 0.0002,
        lngOffset: 0.0003,
        minuteOffset: 2,
        vehicle: "5120-2311 FEL",
        imageUrl: photo(1),
      },
      {
        externalId: "DUPSEED-5120-A3",
        eventSourceId: WASTEVISION,
        latOffset: -0.0002,
        lngOffset: 0.0001,
        minuteOffset: 3,
        vehicle: "5120-2315 REL",
        imageUrl: null,
      },
    ],
  },
  // --- District 20 (Houston, TX) — pair on Airline Dr, 3 min apart
  {
    districtId: 20,
    eventTypeId: 1, // Extra
    base: {
      lat: 29.8171,
      lng: -95.4009,
      address: "8820 AIRLINE DR, HOUSTON, TX",
      customerName: "AIRLINE FARMERS MARKET",
      accountNumber: "5120-7735602",
      route: "RC201",
      severity: "Minimal",
      quantity: "1.00",
      when: at(1, 12, 6),
    },
    members: [
      {
        externalId: "DUPSEED-5120-B1",
        eventSourceId: THIRD_EYE,
        latOffset: 0,
        lngOffset: 0,
        minuteOffset: 0,
        vehicle: "5120-2311 FEL",
        imageUrl: photo(4),
      },
      {
        externalId: "DUPSEED-5120-B2",
        eventSourceId: WASTEVISION,
        latOffset: 0.0003,
        lngOffset: -0.0002,
        minuteOffset: 3,
        vehicle: "5120-2309 FEL",
        imageUrl: photo(2),
      },
    ],
  },
];

async function main() {
  let inserted = 0;
  let refreshed = 0;

  for (const cluster of CLUSTERS) {
    for (const m of cluster.members) {
      const b = cluster.base;
      const values: InsertRouteEvent = {
        districtId: cluster.districtId,
        eventTypeId: cluster.eventTypeId,
        eventSourceId: m.eventSourceId,
        externalId: m.externalId,
        dateOccurred: new Date(b.when.getTime() + m.minuteOffset * 60000),
        vehicle: m.vehicle,
        route: b.route,
        latitude: b.lat + m.latOffset,
        longitude: b.lng + m.lngOffset,
        address: b.address,
        customerName: b.customerName,
        accountNumber: b.accountNumber,
        quantity: b.quantity,
        imageUrl: m.imageUrl,
        imageUrls: [],
        severity: b.severity,
        eventStatus: 0, // open
        dateClosed: null,
        closedBy: null,
        customerRoutes: [],
      };

      const [existing] = await db
        .select({ id: routeEventsTable.id })
        .from(routeEventsTable)
        .where(eq(routeEventsTable.externalId, m.externalId));

      if (existing) {
        await db
          .update(routeEventsTable)
          .set(values)
          .where(eq(routeEventsTable.id, existing.id));
        refreshed++;
      } else {
        await db.insert(routeEventsTable).values(values);
        inserted++;
      }
    }
  }

  console.log(
    `Seeded ${CLUSTERS.length} duplicate clusters (${inserted} inserted, ${refreshed} refreshed).`,
  );
}

main()
  .then(() => pool.end())
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
