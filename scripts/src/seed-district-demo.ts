/**
 * Site-wide demo seed for the Vancouver district (2010) and its
 * Minimal-severity twin district (2010-M, sorts immediately after Vancouver).
 *
 * Seeds a full event queue covering every event type, source, status and
 * severity, duplicate vendor clusters (WasteVision + 3rd Eye reporting the
 * same overage 2–3 minutes apart at the same spot), multi-photo galleries,
 * complete field coverage, event history/notes, and per-account charge
 * history so no field on the site renders empty.
 *
 * Repeatable: each run deletes all seed-owned rows in the two districts
 * (tagged via external_id prefix) and re-creates them from scratch.
 *
 * Run with: pnpm --filter @workspace/scripts run seed-district-demo
 */
import {
  db,
  districtsTable,
  routeEventsTable,
  eventActionsTable,
  serviceCodesTable,
} from "@workspace/db";
import { eq, and, inArray } from "drizzle-orm";

const TAG = "[seed:district-demo]";

const photo = (n: number) => `/event-photos/truck-cam-${n}.jpg`;

function minutesAgo(mins: number): Date {
  return new Date(Date.now() - mins * 60000);
}
function daysAgo(days: number, hoursOffset = 0): Date {
  return new Date(Date.now() - days * 86400000 + hoursOffset * 3600000);
}
function monthsAgo(months: number): Date {
  const d = new Date();
  d.setMonth(d.getMonth() - months);
  return d;
}

type Route = { code: string; service: string; material: string; day: string };
const frontLoad = (code: string, day: string, material = "GARBAGE"): Route => ({
  code,
  service: "FRONT LOAD",
  material,
  day,
});
const rearLoad = (code: string, day: string): Route => ({
  code,
  service: "REAR LOAD",
  material: "GARBAGE",
  day,
});

type EventSpec = {
  key: string;
  typeId: number; // 1 Extra, 2 Contamination, 3 Overloaded, 4 Blocked Container, 5 Not Out
  sourceId: number; // 1 WasteVision, 2 3rd Eye, 3 Manual
  minsAgo: number;
  lat: number;
  lng: number;
  vehicle: string;
  route: string;
  address: string;
  customerName: string;
  account: string; // suffix; prefixed with district number at insert
  billArea: string;
  bin: string;
  lob: string;
  rmo: string;
  qty: string;
  severity: "Severe" | "Minimal";
  status: "open" | "closed" | "charged";
  photos: number[];
  customerSinceMonths: number;
  customerRoutes: Route[];
  closeReason?: string;
  chargeAmount?: string;
  serviceCode?: string;
  notes?: string[];
  /** extra past charges for this account: [daysAgo, amount, paymentStatus][] */
  history?: Array<[number, string, string | null]>;
};

// Duplicate clusters: pairs share location/customer, sources WV then 3rd Eye
// 2–3 minutes later at essentially the same coordinates.
const EVENTS: EventSpec[] = [
  // ---- Cluster 1 (Overloaded, open/open) ----
  {
    key: "c1-wv",
    typeId: 3,
    sourceId: 1,
    minsAgo: 132,
    lat: 45.6387,
    lng: -122.6615,
    vehicle: "2010-118 FEL",
    route: "VA204",
    address: "7720 NE VANCOUVER MALL DR, VANCOUVER, WA",
    customerName: "CASCADE STATION RETAIL",
    account: "4410092",
    billArea: "CLARK Z2",
    bin: "BIN-20115",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Severe",
    status: "open",
    photos: [6, 1, 8, 12],
    customerSinceMonths: 103,
    customerRoutes: [
      frontLoad("VA204", "TUESDAY"),
      frontLoad("VA406", "THURSDAY", "RECYCLE"),
    ],
    history: [
      [12, "60.0000", "PAID"],
      [41, "60.0000", "PAID"],
      [77, "70.0000", "REFUNDED"],
    ],
  },
  {
    key: "c1-3e",
    typeId: 3,
    sourceId: 2,
    minsAgo: 129, // 3 minutes after the WasteVision report
    lat: 45.63872,
    lng: -122.66148,
    vehicle: "2010-118 FEL",
    route: "VA204",
    address: "7720 NE VANCOUVER MALL DR, VANCOUVER, WA",
    customerName: "CASCADE STATION RETAIL",
    account: "4410092",
    billArea: "CLARK Z2",
    bin: "BIN-20115",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Severe",
    status: "open",
    photos: [9, 6, 2],
    customerSinceMonths: 103,
    customerRoutes: [
      frontLoad("VA204", "TUESDAY"),
      frontLoad("VA406", "THURSDAY", "RECYCLE"),
    ],
  },
  // ---- Cluster 2 (Extra, charged today / closed dup) ----
  {
    key: "c2-wv",
    typeId: 1,
    sourceId: 1,
    minsAgo: 425,
    lat: 45.628,
    lng: -122.674,
    vehicle: "2010-121 FEL",
    route: "VA108",
    address: "3311 MAIN ST, VANCOUVER, WA",
    customerName: "UPTOWN LOFTS",
    account: "4433001",
    billArea: "CLARK Z1",
    bin: "BIN-31200",
    lob: "Commercial",
    rmo: "Linked",
    qty: "2.00",
    severity: "Severe",
    status: "charged",
    photos: [1, 8, 3, 10],
    customerSinceMonths: 16,
    customerRoutes: [frontLoad("VA108", "MONDAY")],
    chargeAmount: "70.0000",
    serviceCode: "EXTRA-COM",
    notes: ["Customer called ahead about extra bags; charge approved by CSR."],
    history: [
      [25, "70.0000", "PAID"],
      [58, "70.0000", "PAID"],
    ],
  },
  {
    key: "c2-3e",
    typeId: 1,
    sourceId: 2,
    minsAgo: 423, // 2 minutes later
    lat: 45.62803,
    lng: -122.67395,
    vehicle: "2010-121 FEL",
    route: "VA108",
    address: "3311 MAIN ST, VANCOUVER, WA",
    customerName: "UPTOWN LOFTS",
    account: "4433001",
    billArea: "CLARK Z1",
    bin: "BIN-31200",
    lob: "Commercial",
    rmo: "Linked",
    qty: "2.00",
    severity: "Severe",
    status: "closed",
    photos: [11, 1],
    customerSinceMonths: 16,
    customerRoutes: [frontLoad("VA108", "MONDAY")],
    closeReason: "Duplicate Event",
    notes: ["Duplicate of WasteVision report at same address; closing."],
  },
  // ---- Cluster 3 (Contamination, open pair) ----
  {
    key: "c3-wv",
    typeId: 2,
    sourceId: 1,
    minsAgo: 1510, // ~25h ago
    lat: 45.6512,
    lng: -122.6021,
    vehicle: "2010-127 REL",
    route: "VR310",
    address: "9812 NE FOURTH PLAIN BLVD, VANCOUVER, WA",
    customerName: "ORCHARDS MARKETPLACE",
    account: "4471180",
    billArea: "CLARK Z3",
    bin: "BIN-44518",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Severe",
    status: "open",
    photos: [4, 11, 5],
    customerSinceMonths: 58,
    customerRoutes: [
      frontLoad("VR310", "WEDNESDAY", "RECYCLE"),
      frontLoad("VA202", "TUESDAY"),
    ],
    history: [[19, "90.0000", "PAID"]],
  },
  {
    key: "c3-3e",
    typeId: 2,
    sourceId: 2,
    minsAgo: 1507.5, // 2.5 minutes later
    lat: 45.65123,
    lng: -122.60205,
    vehicle: "2010-127 REL",
    route: "VR310",
    address: "9812 NE FOURTH PLAIN BLVD, VANCOUVER, WA",
    customerName: "ORCHARDS MARKETPLACE",
    account: "4471180",
    billArea: "CLARK Z3",
    bin: "BIN-44518",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Severe",
    status: "open",
    photos: [13, 4, 9],
    customerSinceMonths: 58,
    customerRoutes: [
      frontLoad("VR310", "WEDNESDAY", "RECYCLE"),
      frontLoad("VA202", "TUESDAY"),
    ],
  },
  // ---- Singles covering remaining types/sources/statuses ----
  {
    key: "s1",
    typeId: 4, // Blocked Container
    sourceId: 1,
    minsAgo: 220,
    lat: 45.6231,
    lng: -122.6698,
    vehicle: "2010-118 FEL",
    route: "VA204",
    address: "415 W 8TH ST, VANCOUVER, WA",
    customerName: "COLUMBIA CENTER OFFICES",
    account: "4408831",
    billArea: "CLARK Z1",
    bin: "BIN-11842",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Minimal",
    status: "open",
    photos: [13, 6, 2, 7],
    customerSinceMonths: 87,
    customerRoutes: [frontLoad("VA204", "TUESDAY")],
    history: [[33, "15.0000", "PAID"]],
  },
  {
    key: "s2",
    typeId: 5, // Not Out
    sourceId: 2,
    minsAgo: 2930, // ~2 days ago
    lat: 45.6119,
    lng: -122.5567,
    vehicle: "2010-133 RSL",
    route: "VR122",
    address: "11605 SE MILL PLAIN BLVD, VANCOUVER, WA",
    customerName: "NGUYEN, DANIEL",
    account: "4490277",
    billArea: "CLARK RES Z5",
    bin: "BIN-77031",
    lob: "Residential",
    rmo: "Not linked",
    qty: "1.00",
    severity: "Minimal",
    status: "closed",
    photos: [3, 10, 12],
    customerSinceMonths: 29,
    customerRoutes: [rearLoad("VR122", "FRIDAY")],
    closeReason: "Not an Overfill",
    notes: ["Cart was out by the time the follow-up truck arrived."],
  },
  {
    key: "s3",
    typeId: 1, // Extra, Manual
    sourceId: 3,
    minsAgo: 95,
    lat: 45.6448,
    lng: -122.6402,
    vehicle: "2010-140 FEL",
    route: "VA301",
    address: "5000 E 18TH ST, VANCOUVER, WA",
    customerName: "EVERGREEN SCHOOL DISTRICT #12",
    account: "4402209",
    billArea: "CLARK Z2",
    bin: "BIN-55290",
    lob: "Commercial",
    rmo: "Linked",
    qty: "3.00",
    severity: "Minimal",
    status: "open",
    photos: [8, 5, 11],
    customerSinceMonths: 148,
    customerRoutes: [
      frontLoad("VA301", "MONDAY"),
      frontLoad("VA301", "THURSDAY"),
    ],
    notes: ["Driver reported extra pallets of boxed waste at loading dock."],
  },
  {
    key: "s4",
    typeId: 3, // Overloaded, charged (yesterday)
    sourceId: 1,
    minsAgo: 1740,
    lat: 45.6055,
    lng: -122.6811,
    vehicle: "2010-121 FEL",
    route: "VA108",
    address: "100 COLUMBIA WAY, VANCOUVER, WA",
    customerName: "WATERFRONT GRILL",
    account: "4455872",
    billArea: "CLARK Z1",
    bin: "BIN-62204",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Severe",
    status: "charged",
    photos: [2, 9, 6, 13],
    customerSinceMonths: 41,
    customerRoutes: [frontLoad("VA108", "MONDAY"), frontLoad("VA508", "FRIDAY")],
    chargeAmount: "60.0000",
    serviceCode: "OVERLOAD",
    notes: ["Lid open >45 degrees, photos confirm overload."],
    history: [
      [14, "60.0000", "PAID"],
      [49, "60.0000", null],
      [83, "60.0000", "PAID"],
    ],
  },
  {
    key: "s5",
    typeId: 2, // Contamination, Manual, closed
    sourceId: 3,
    minsAgo: 4310, // ~3 days ago
    lat: 45.6591,
    lng: -122.6939,
    vehicle: "2010-127 REL",
    route: "VR310",
    address: "2921 NW LOWER RIVER RD, VANCOUVER, WA",
    customerName: "PORT OF VANCOUVER TERMINAL 3",
    account: "4419904",
    billArea: "CLARK Z4",
    bin: "BIN-90112",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Minimal",
    status: "closed",
    photos: [7, 12, 4],
    customerSinceMonths: 194,
    customerRoutes: [frontLoad("VR310", "WEDNESDAY", "RECYCLE")],
    closeReason: "Courtesy Close",
    notes: ["First contamination event for this account; courtesy close."],
  },
  {
    key: "s6",
    typeId: 4, // Blocked Container, 3rd Eye, open
    sourceId: 2,
    minsAgo: 305,
    lat: 45.6172,
    lng: -122.6533,
    vehicle: "2010-140 FEL",
    route: "VA301",
    address: "700 SE COLUMBIA SHORES BLVD, VANCOUVER, WA",
    customerName: "SHORES MEDICAL PLAZA",
    account: "4462215",
    billArea: "CLARK Z2",
    bin: "BIN-38855",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Severe",
    status: "open",
    photos: [13, 8, 1],
    customerSinceMonths: 66,
    customerRoutes: [frontLoad("VA301", "MONDAY")],
  },
  {
    key: "s7",
    typeId: 5, // Not Out, Manual, open
    sourceId: 3,
    minsAgo: 2650,
    lat: 45.6702,
    lng: -122.5519,
    vehicle: "2010-133 RSL",
    route: "VR122",
    address: "14508 NE 20TH AVE, VANCOUVER, WA",
    customerName: "RAMIREZ, GLORIA",
    account: "4477310",
    billArea: "CLARK RES Z6",
    bin: "BIN-70558",
    lob: "Residential",
    rmo: "Not linked",
    qty: "1.00",
    severity: "Minimal",
    status: "open",
    photos: [10, 3, 5, 9],
    customerSinceMonths: 8,
    customerRoutes: [rearLoad("VR122", "FRIDAY")],
  },
  {
    key: "s8",
    typeId: 1, // Extra, charged today (drives chargedToday > 0)
    sourceId: 2,
    minsAgo: 55,
    lat: 45.6329,
    lng: -122.5989,
    vehicle: "2010-118 FEL",
    route: "VA204",
    address: "8802 MILL PLAIN BLVD, VANCOUVER, WA",
    customerName: "MILL PLAIN CROSSING",
    account: "4425567",
    billArea: "CLARK Z3",
    bin: "BIN-24471",
    lob: "Commercial",
    rmo: "Linked",
    qty: "1.00",
    severity: "Severe",
    status: "charged",
    photos: [12, 2, 7],
    customerSinceMonths: 122,
    customerRoutes: [
      frontLoad("VA204", "TUESDAY"),
      frontLoad("VA604", "SATURDAY"),
    ],
    chargeAmount: "70.0000",
    serviceCode: "EXTRA-COM",
    notes: ["Recurring extra volume; recommended service level review."],
    history: [
      [22, "70.0000", "PAID"],
      [51, "70.0000", "REFUNDED"],
      [88, "70.0000", "PAID"],
    ],
  },
];

const TWIN = {
  number: "2010-M",
  name: "VANCOUVER MINIMAL",
  region: "Western",
  haulingSystem: 1,
};

const SERVICE_CODES = [
  { code: "EXTRA-COM", description: "Extra pickup - Commercial", amount: "70.0000" },
  { code: "CONTAM", description: "Contamination charge", amount: "90.0000" },
  { code: "OVERLOAD", description: "Overloaded container charge", amount: "60.0000" },
];

async function cleanDistrict(districtId: number) {
  const rows = await db
    .select({ id: routeEventsTable.id })
    .from(routeEventsTable)
    .where(eq(routeEventsTable.districtId, districtId));
  const ids = rows.map((r) => r.id);
  if (ids.length > 0) {
    await db
      .delete(eventActionsTable)
      .where(inArray(eventActionsTable.routeEventId, ids));
    await db.delete(routeEventsTable).where(inArray(routeEventsTable.id, ids));
  }
  console.log(`Cleaned ${ids.length} events from district ${districtId}`);
}

async function seedDistrict(
  districtId: number,
  districtNumber: string,
  opts: { severityOverride?: "Minimal" } = {},
) {
  // Service-code id lookup for charge actions
  const codes = await db
    .select()
    .from(serviceCodesTable)
    .where(eq(serviceCodesTable.districtId, districtId));
  const codeIds = new Map(codes.map((c) => [c.code, c.id]));

  for (const s of EVENTS) {
    const closed = s.status !== "open";
    const dateOccurred = minutesAgo(s.minsAgo);
    const dateClosed = closed
      ? new Date(dateOccurred.getTime() + 45 * 60000)
      : null;
    const photos = s.photos.map(photo);
    const [ev] = await db
      .insert(routeEventsTable)
      .values({
        districtId,
        eventTypeId: s.typeId,
        eventSourceId: s.sourceId,
        externalId: `${TAG}-${districtNumber}-${s.key}`,
        dateOccurred,
        vehicle: s.vehicle,
        route: s.route,
        latitude: s.lat,
        longitude: s.lng,
        address: s.address,
        customerName: s.customerName,
        accountNumber: `${districtNumber}-${s.account}`,
        billArea: s.billArea,
        binSerialNumber: s.bin,
        lob: s.lob,
        rmoStatus: s.rmo,
        quantity: s.qty,
        imageUrl: photos[0]!,
        imageUrls: photos.slice(1),
        severity: opts.severityOverride ?? s.severity,
        customerSince: monthsAgo(s.customerSinceMonths),
        eventStatus: closed ? 1 : 0,
        dateClosed,
        closedBy: closed ? "Kyle.Patrick" : null,
        customerRoutes: s.customerRoutes,
      })
      .returning();
    const eventId = ev!.id;

    // Notes (history entries)
    for (const note of s.notes ?? []) {
      await db.insert(eventActionsTable).values({
        routeEventId: eventId,
        actionType: "note",
        isFinal: false,
        notes: note,
        billedStatementNumber: TAG,
        createdBy: "Kyle.Patrick",
        dateCreated: new Date(dateOccurred.getTime() + 20 * 60000),
      });
    }

    // Final close/charge action
    if (s.status === "closed") {
      await db.insert(eventActionsTable).values({
        routeEventId: eventId,
        actionType: "close",
        isFinal: true,
        closeReason: s.closeReason ?? "Not an Overfill",
        billedStatementNumber: TAG,
        createdBy: "Kyle.Patrick",
        dateCreated: dateClosed!,
      });
    } else if (s.status === "charged") {
      await db.insert(eventActionsTable).values({
        routeEventId: eventId,
        actionType: "charge",
        isFinal: true,
        serviceCodeId: s.serviceCode ? (codeIds.get(s.serviceCode) ?? null) : null,
        chargeAmount: s.chargeAmount ?? "70.0000",
        chargeQuantity: s.qty,
        paymentStatus: "PAID",
        notes: "Overage charge applied to account.",
        billedStatementNumber: TAG,
        createdBy: "Kyle.Patrick",
        dateCreated: dateClosed!,
      });
    }

    // Past charge history for the account (feeds 30/60/90-day statistics)
    for (const [days, amount, paymentStatus] of s.history ?? []) {
      await db.insert(eventActionsTable).values({
        routeEventId: eventId,
        actionType: "charge",
        isFinal: false,
        chargeAmount: amount,
        chargeQuantity: "1.00",
        paymentStatus,
        notes: "Overage charge applied to account.",
        billedStatementNumber: `${TAG}-history`,
        createdBy: "Kyle.Patrick",
        dateCreated: daysAgo(days, 3),
      });
    }
  }
  console.log(
    `Seeded ${EVENTS.length} events into district ${districtNumber} (id ${districtId})`,
  );
}

async function main() {
  // 1. Vancouver district (2010) must exist
  const [vancouver] = await db
    .select()
    .from(districtsTable)
    .where(eq(districtsTable.number, "2010"));
  if (!vancouver) {
    throw new Error("Vancouver district (2010) not found; run base seed first.");
  }

  // 2. Twin district, sorted right after 2010 and before 2011
  let [twin] = await db
    .select()
    .from(districtsTable)
    .where(eq(districtsTable.number, TWIN.number));
  if (!twin) {
    [twin] = await db.insert(districtsTable).values(TWIN).returning();
    console.log(`Created twin district ${TWIN.number} (id ${twin!.id})`);
  }

  // 3. Twin service codes (mirror Vancouver's)
  for (const c of SERVICE_CODES) {
    const existing = await db
      .select()
      .from(serviceCodesTable)
      .where(
        and(
          eq(serviceCodesTable.districtId, twin!.id),
          eq(serviceCodesTable.code, c.code),
        ),
      );
    if (existing.length === 0) {
      await db
        .insert(serviceCodesTable)
        .values({ districtId: twin!.id, ...c, active: true });
    }
  }

  // 4. Clean both districts, then re-create the full datasets
  await cleanDistrict(vancouver.id);
  await cleanDistrict(twin!.id);
  await seedDistrict(vancouver.id, "2010");
  await seedDistrict(twin!.id, TWIN.number, { severityOverride: "Minimal" });

  console.log("District demo seed complete.");
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error(err);
    process.exit(1);
  },
);
