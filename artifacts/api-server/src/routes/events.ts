import { Router, type IRouter } from "express";
import { and, eq, ilike, or, sql, asc, desc } from "drizzle-orm";
import {
  db,
  districtsTable,
  eventTypesTable,
  eventSourcesTable,
  serviceCodesTable,
  routeEventsTable,
  eventActionsTable,
  accountFlagsTable,
} from "@workspace/db";
import {
  ListDistrictsResponse,
  GetDistrictSummaryParams,
  GetDistrictSummaryResponse,
  ListEventsQueryParams,
  ListEventsResponse,
  ListDistrictServiceCodesParams,
  ListDistrictServiceCodesResponse,
  ListEventTypesResponse,
  GetEventParams,
  GetEventResponse,
  AddEventNoteParams,
  AddEventNoteBody,
  AddEventNoteResponse,
  ChargeEventParams,
  ChargeEventBody,
  ChargeEventResponse,
  EmailEventParams,
  EmailEventBody,
  EmailEventResponse,
  CloseEventParams,
  CloseEventBody,
  CloseEventResponse,
  BulkCloseEventsBody,
  BulkCloseEventsResponse,
} from "@workspace/api-zod";
import { inArray, gte, ne, notExists } from "drizzle-orm";

const router: IRouter = Router();

const CURRENT_USER = "Kyle.Patrick";

// Close reason that flags the account so its overages are hidden from queues
const CONTRACT_CLOSE_REASON = "Contract - No Overages";

/** SQL condition: the event's account is not flagged as contract/no-overages. */
function accountNotFlagged() {
  return notExists(
    db
      .select({ id: accountFlagsTable.id })
      .from(accountFlagsTable)
      .where(
        and(
          eq(accountFlagsTable.districtId, routeEventsTable.districtId),
          eq(accountFlagsTable.accountNumber, routeEventsTable.accountNumber),
          eq(accountFlagsTable.flag, "contract_no_overages"),
        ),
      ),
  );
}

function serializeAction(a: typeof eventActionsTable.$inferSelect) {
  return {
    id: a.id,
    routeEventId: a.routeEventId,
    actionType: a.actionType,
    isFinal: a.isFinal,
    notes: a.notes,
    closeReason: a.closeReason,
    serviceCodeId: a.serviceCodeId,
    chargeAmount: a.chargeAmount === null ? null : Number(a.chargeAmount),
    chargeQuantity: a.chargeQuantity === null ? null : Number(a.chargeQuantity),
    paymentStatus: a.paymentStatus,
    createdBy: a.createdBy,
    dateCreated: a.dateCreated.toISOString(),
  };
}

/** Primary image first, then any extra photos, deduplicated. */
function allImages(e: typeof routeEventsTable.$inferSelect): string[] {
  const list = [e.imageUrl, ...(e.imageUrls ?? [])].filter(
    (u): u is string => !!u,
  );
  return [...new Set(list)];
}

function monthsBetween(from: Date, to: Date): number {
  return Math.max(
    0,
    (to.getFullYear() - from.getFullYear()) * 12 +
      (to.getMonth() - from.getMonth()),
  );
}

function serializeListItem(
  e: typeof routeEventsTable.$inferSelect,
  eventTypeName: string,
  eventSourceName: string,
) {
  return {
    id: e.id,
    districtId: e.districtId,
    eventTypeId: e.eventTypeId,
    eventTypeName,
    eventSourceName,
    dateOccurred: e.dateOccurred.toISOString(),
    vehicle: e.vehicle,
    route: e.route,
    customerName: e.customerName,
    accountNumber: e.accountNumber,
    address: e.address,
    quantity: e.quantity === null ? null : Number(e.quantity),
    imageUrl: e.imageUrl,
    imageUrls: allImages(e),
    severity: e.severity,
    eventStatus: e.eventStatus,
    dateClosed: e.dateClosed ? e.dateClosed.toISOString() : null,
    closedBy: e.closedBy,
  };
}

router.get("/districts", async (_req, res): Promise<void> => {
  const districts = await db
    .select()
    .from(districtsTable)
    .where(eq(districtsTable.active, true))
    .orderBy(asc(districtsTable.number));
  res.json(ListDistrictsResponse.parse(districts));
});

router.get("/event-types", async (_req, res): Promise<void> => {
  const types = await db
    .select()
    .from(eventTypesTable)
    .where(eq(eventTypesTable.active, true))
    .orderBy(asc(eventTypesTable.name));
  res.json(ListEventTypesResponse.parse(types));
});

router.get(
  "/districts/:districtId/summary",
  async (req, res): Promise<void> => {
    const params = GetDistrictSummaryParams.safeParse(req.params);
    if (!params.success) {
      res.status(400).json({ error: params.error.message });
      return;
    }
    const { districtId } = params.data;

    const [district] = await db
      .select()
      .from(districtsTable)
      .where(eq(districtsTable.id, districtId));
    if (!district) {
      res.status(404).json({ error: "District not found" });
      return;
    }

    const [counts] = await db
      .select({
        openCount: sql<number>`count(*) filter (where ${routeEventsTable.eventStatus} = 0)`,
        closedCount: sql<number>`count(*) filter (where ${routeEventsTable.eventStatus} = 1)`,
      })
      .from(routeEventsTable)
      .where(
        and(eq(routeEventsTable.districtId, districtId), accountNotFlagged()),
      );

    const [charges] = await db
      .select({
        chargedToday: sql<number>`count(*) filter (where ${eventActionsTable.actionType} = 'charge' and ${eventActionsTable.dateCreated} >= date_trunc('day', now()))`,
        totalChargedAmount: sql<number>`coalesce(sum(${eventActionsTable.chargeAmount} * coalesce(${eventActionsTable.chargeQuantity}, 1)) filter (where ${eventActionsTable.actionType} = 'charge'), 0)`,
      })
      .from(eventActionsTable)
      .innerJoin(
        routeEventsTable,
        eq(eventActionsTable.routeEventId, routeEventsTable.id),
      )
      .where(
        and(eq(routeEventsTable.districtId, districtId), accountNotFlagged()),
      );

    const byEventType = await db
      .select({
        eventTypeId: eventTypesTable.id,
        eventTypeName: eventTypesTable.name,
        openCount: sql<number>`count(*) filter (where ${routeEventsTable.eventStatus} = 0)`,
      })
      .from(routeEventsTable)
      .innerJoin(
        eventTypesTable,
        eq(routeEventsTable.eventTypeId, eventTypesTable.id),
      )
      .where(
        and(eq(routeEventsTable.districtId, districtId), accountNotFlagged()),
      )
      .groupBy(eventTypesTable.id, eventTypesTable.name)
      .orderBy(asc(eventTypesTable.name));

    res.json(
      GetDistrictSummaryResponse.parse({
        districtId,
        openCount: Number(counts?.openCount ?? 0),
        closedCount: Number(counts?.closedCount ?? 0),
        chargedToday: Number(charges?.chargedToday ?? 0),
        totalChargedAmount: Number(charges?.totalChargedAmount ?? 0),
        byEventType: byEventType.map((r) => ({
          eventTypeId: r.eventTypeId,
          eventTypeName: r.eventTypeName,
          openCount: Number(r.openCount),
        })),
      }),
    );
  },
);

router.get(
  "/districts/:districtId/service-codes",
  async (req, res): Promise<void> => {
    const params = ListDistrictServiceCodesParams.safeParse(req.params);
    if (!params.success) {
      res.status(400).json({ error: params.error.message });
      return;
    }
    const codes = await db
      .select()
      .from(serviceCodesTable)
      .where(
        and(
          eq(serviceCodesTable.districtId, params.data.districtId),
          eq(serviceCodesTable.active, true),
        ),
      )
      .orderBy(asc(serviceCodesTable.code));
    res.json(
      ListDistrictServiceCodesResponse.parse(
        codes.map((c) => ({ ...c, amount: Number(c.amount) })),
      ),
    );
  },
);

router.get("/events", async (req, res): Promise<void> => {
  const query = ListEventsQueryParams.safeParse(req.query);
  if (!query.success) {
    res.status(400).json({ error: query.error.message });
    return;
  }
  const { districtId, status, eventTypeId, search } = query.data;

  const conditions = [
    eq(routeEventsTable.districtId, districtId),
    accountNotFlagged(),
  ];
  if (status === "open" || status === undefined) {
    conditions.push(eq(routeEventsTable.eventStatus, 0));
  } else if (status === "closed") {
    conditions.push(eq(routeEventsTable.eventStatus, 1));
  }
  if (eventTypeId !== undefined) {
    conditions.push(eq(routeEventsTable.eventTypeId, eventTypeId));
  }
  if (search) {
    const pattern = `%${search}%`;
    const searchCond = or(
      ilike(routeEventsTable.customerName, pattern),
      ilike(routeEventsTable.address, pattern),
      ilike(routeEventsTable.accountNumber, pattern),
      ilike(routeEventsTable.route, pattern),
      ilike(routeEventsTable.vehicle, pattern),
    );
    if (searchCond) conditions.push(searchCond);
  }

  const rows = await db
    .select({
      event: routeEventsTable,
      eventTypeName: eventTypesTable.name,
      eventSourceName: eventSourcesTable.name,
    })
    .from(routeEventsTable)
    .innerJoin(
      eventTypesTable,
      eq(routeEventsTable.eventTypeId, eventTypesTable.id),
    )
    .innerJoin(
      eventSourcesTable,
      eq(routeEventsTable.eventSourceId, eventSourcesTable.id),
    )
    .where(and(...conditions))
    .orderBy(desc(routeEventsTable.dateOccurred));

  res.json(
    ListEventsResponse.parse(
      rows.map((r) =>
        serializeListItem(r.event, r.eventTypeName, r.eventSourceName),
      ),
    ),
  );
});

// --- Nearby-overage matching tunables ---
/** Max great-circle distance (meters) for an event to count as "nearby". */
const NEARBY_RADIUS_METERS = 300;
/** Time window (± minutes around the event) for nearby matching. */
const NEARBY_WINDOW_MINUTES = 60;
/** Max number of nearby events returned. */
const NEARBY_MAX_RESULTS = 10;

/**
 * Nearby overages: same district within ±NEARBY_WINDOW_MINUTES and a true
 * haversine distance of NEARBY_RADIUS_METERS, closest first, capped at
 * NEARBY_MAX_RESULTS rows.
 */
async function queryNearbyRows(e: typeof routeEventsTable.$inferSelect) {
  const windowMs = NEARBY_WINDOW_MINUTES * 60000;
  // Haversine distance in meters between the anchor event and each row.
  const distanceMeters = sql<number>`(
    2 * 6371000 * asin(
      sqrt(
        pow(sin(radians(${routeEventsTable.latitude} - ${e.latitude}) / 2), 2)
        + cos(radians(${e.latitude}))
        * cos(radians(${routeEventsTable.latitude}))
        * pow(sin(radians(${routeEventsTable.longitude} - ${e.longitude}) / 2), 2)
      )
    )
  )`;
  return db
    .select()
    .from(routeEventsTable)
    .where(
      and(
        eq(routeEventsTable.districtId, e.districtId),
        ne(routeEventsTable.id, e.id),
        gte(
          routeEventsTable.dateOccurred,
          new Date(e.dateOccurred.getTime() - windowMs),
        ),
        sql`${routeEventsTable.dateOccurred} <= ${new Date(e.dateOccurred.getTime() + windowMs)}`,
        sql`${distanceMeters} <= ${NEARBY_RADIUS_METERS}`,
      ),
    )
    .orderBy(sql`${distanceMeters} asc`, asc(routeEventsTable.dateOccurred))
    .limit(NEARBY_MAX_RESULTS);
}

async function loadEventDetail(eventId: number) {
  const [row] = await db
    .select({
      event: routeEventsTable,
      eventTypeName: eventTypesTable.name,
      eventSourceName: eventSourcesTable.name,
      districtNumber: districtsTable.number,
    })
    .from(routeEventsTable)
    .innerJoin(
      eventTypesTable,
      eq(routeEventsTable.eventTypeId, eventTypesTable.id),
    )
    .innerJoin(
      eventSourcesTable,
      eq(routeEventsTable.eventSourceId, eventSourcesTable.id),
    )
    .innerJoin(districtsTable, eq(routeEventsTable.districtId, districtsTable.id))
    .where(eq(routeEventsTable.id, eventId));
  if (!row) return null;

  const actions = await db
    .select()
    .from(eventActionsTable)
    .where(eq(eventActionsTable.routeEventId, eventId))
    .orderBy(desc(eventActionsTable.dateCreated));

  const e = row.event;

  // --- Overage statistics: bounded to the last 90 days of charges ---
  const now = new Date();
  const cutoff90 = new Date(now.getTime() - 90 * 86400000);
  const accountChargeFilter = and(
    eq(routeEventsTable.accountNumber, e.accountNumber),
    eq(routeEventsTable.districtId, e.districtId),
    eq(eventActionsTable.actionType, "charge"),
  );
  const accountCharges = await db
    .select({ action: eventActionsTable })
    .from(eventActionsTable)
    .innerJoin(
      routeEventsTable,
      eq(eventActionsTable.routeEventId, routeEventsTable.id),
    )
    .where(and(accountChargeFilter, gte(eventActionsTable.dateCreated, cutoff90)))
    .orderBy(desc(eventActionsTable.dateCreated));

  // Most recent 3 charges regardless of window
  const recentCharges = await db
    .select({ action: eventActionsTable })
    .from(eventActionsTable)
    .innerJoin(
      routeEventsTable,
      eq(eventActionsTable.routeEventId, routeEventsTable.id),
    )
    .where(accountChargeFilter)
    .orderBy(desc(eventActionsTable.dateCreated))
    .limit(3);

  // Events for this account in the last 90 days (for per-window event counts)
  const accountEventDates = await db
    .select({ dateOccurred: routeEventsTable.dateOccurred })
    .from(routeEventsTable)
    .where(
      and(
        eq(routeEventsTable.accountNumber, e.accountNumber),
        eq(routeEventsTable.districtId, e.districtId),
        gte(routeEventsTable.dateOccurred, cutoff90),
      ),
    );

  const windows = [30, 60, 90].map((days) => {
    const cutoff = new Date(now.getTime() - days * 86400000);
    const inWindow = accountCharges.filter(
      ({ action }) => action.dateCreated >= cutoff,
    );
    const paid = inWindow.filter(
      ({ action }) => action.paymentStatus === "PAID",
    );
    const refunded = inWindow.filter(
      ({ action }) => action.paymentStatus === "REFUNDED",
    );
    const sum = (rows: typeof inWindow) =>
      rows.reduce(
        (acc, { action }) =>
          acc +
          Number(action.chargeAmount ?? 0) *
            Number(action.chargeQuantity ?? 1),
        0,
      );
    return {
      days,
      eventsCount: accountEventDates.filter((r) => r.dateOccurred >= cutoff)
        .length,
      chargedCount: inWindow.length,
      chargedAmount: sum(inWindow),
      refundedCount: refunded.length,
      refundedAmount: sum(refunded),
      netPaid: sum(paid) - sum(refunded),
    };
  });

  const statistics = {
    tenureMonths: e.customerSince ? monthsBetween(e.customerSince, now) : null,
    customerSince: e.customerSince ? e.customerSince.toISOString() : null,
    lastChargeDate: recentCharges[0]
      ? recentCharges[0].action.dateCreated.toISOString()
      : null,
    windows,
  };

  const lastCharges = recentCharges.map(({ action }) => ({
    id: action.id,
    dateCreated: action.dateCreated.toISOString(),
    amount:
      Number(action.chargeAmount ?? 0) * Number(action.chargeQuantity ?? 1),
    paymentStatus: action.paymentStatus,
  }));

  const nearbyRows = await queryNearbyRows(e);

  const nearbyIds = nearbyRows.map((n) => n.id);
  const chargedNearbyIds = new Set<number>();
  if (nearbyIds.length > 0) {
    const chargeActions = await db
      .select({ routeEventId: eventActionsTable.routeEventId })
      .from(eventActionsTable)
      .where(
        and(
          inArray(eventActionsTable.routeEventId, nearbyIds),
          eq(eventActionsTable.actionType, "charge"),
        ),
      );
    for (const c of chargeActions) chargedNearbyIds.add(c.routeEventId);
  }

  const nearbyEvents = nearbyRows.map((n) => ({
    id: n.id,
    imageUrl: n.imageUrl,
    dateOccurred: n.dateOccurred.toISOString(),
    secondsOffset: Math.round(
      (n.dateOccurred.getTime() - e.dateOccurred.getTime()) / 1000,
    ),
    eventStatus: n.eventStatus,
    status:
      n.eventStatus === 0
        ? "Open"
        : chargedNearbyIds.has(n.id)
          ? "Charged"
          : "Dismissed",
    address: n.address,
    customerName: n.customerName,
  }));

  return {
    ...serializeListItem(e, row.eventTypeName, row.eventSourceName),
    externalId: e.externalId,
    billArea: e.billArea,
    binSerialNumber: e.binSerialNumber,
    lob: e.lob,
    rmoStatus: e.rmoStatus,
    latitude: e.latitude,
    longitude: e.longitude,
    routes: e.customerRoutes,
    actions: actions.map(serializeAction),
    statistics,
    nearbyEvents,
    lastCharges,
    shareLinks: {
      event: `https://events.wcnx.org/${row.districtNumber}/events/${e.id}`,
      photo: `https://events.wcnx.org/${row.districtNumber}/imageproxy?url=${encodeURIComponent(e.imageUrl ?? "")}`,
      source: `https://monitor.wastevision.ai/Media/Details?mediaId=${e.externalId ?? e.id}`,
    },
  };
}

router.get("/events/:eventId", async (req, res): Promise<void> => {
  const params = GetEventParams.safeParse(req.params);
  if (!params.success) {
    res.status(400).json({ error: params.error.message });
    return;
  }
  const detail = await loadEventDetail(params.data.eventId);
  if (!detail) {
    res.status(404).json({ error: "Event not found" });
    return;
  }
  res.json(GetEventResponse.parse(detail));
});

async function getOpenEvent(eventId: number) {
  const [event] = await db
    .select()
    .from(routeEventsTable)
    .where(eq(routeEventsTable.id, eventId));
  return event ?? null;
}

router.post("/events/:eventId/notes", async (req, res): Promise<void> => {
  const params = AddEventNoteParams.safeParse(req.params);
  if (!params.success) {
    res.status(400).json({ error: params.error.message });
    return;
  }
  const body = AddEventNoteBody.safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.message });
    return;
  }
  const event = await getOpenEvent(params.data.eventId);
  if (!event) {
    res.status(404).json({ error: "Event not found" });
    return;
  }
  const [action] = await db
    .insert(eventActionsTable)
    .values({
      routeEventId: event.id,
      actionType: "note",
      isFinal: false,
      notes: body.data.notes,
      createdBy: CURRENT_USER,
    })
    .returning();
  res.status(201).json(AddEventNoteResponse.parse(serializeAction(action!)));
});

router.post("/events/:eventId/charge", async (req, res): Promise<void> => {
  const params = ChargeEventParams.safeParse(req.params);
  if (!params.success) {
    res.status(400).json({ error: params.error.message });
    return;
  }
  const body = ChargeEventBody.safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.message });
    return;
  }
  const event = await getOpenEvent(params.data.eventId);
  if (!event) {
    res.status(404).json({ error: "Event not found" });
    return;
  }
  const keepOpen = body.data.keepOpen ?? false;
  const action = await db.transaction(async (tx) => {
    // Block charges for contract-flagged accounts, atomically with the insert
    const [flag] = await tx
      .select({ id: accountFlagsTable.id })
      .from(accountFlagsTable)
      .where(
        and(
          eq(accountFlagsTable.districtId, event.districtId),
          eq(accountFlagsTable.accountNumber, event.accountNumber),
          eq(accountFlagsTable.flag, "contract_no_overages"),
        ),
      );
    if (flag) return "flagged" as const;

    // Re-check open status inside the transaction to avoid racing a close
    const [current] = await tx
      .select({ eventStatus: routeEventsTable.eventStatus })
      .from(routeEventsTable)
      .where(eq(routeEventsTable.id, event.id))
      .for("update");
    if (!current || current.eventStatus !== 0) return "closed" as const;

    const [inserted] = await tx
      .insert(eventActionsTable)
      .values({
        routeEventId: event.id,
        actionType: "charge",
        isFinal: !keepOpen,
        serviceCodeId: body.data.serviceCodeId,
        chargeAmount: body.data.amount.toFixed(4),
        chargeQuantity: body.data.quantity.toFixed(2),
        createdBy: CURRENT_USER,
      })
      .returning();
    if (!keepOpen) {
      await tx
        .update(routeEventsTable)
        .set({ eventStatus: 1, dateClosed: new Date(), closedBy: CURRENT_USER })
        .where(eq(routeEventsTable.id, event.id));
    }
    return inserted!;
  });
  if (action === "flagged") {
    res.status(409).json({
      error: "Account is under contract; overages cannot be charged",
    });
    return;
  }
  if (action === "closed") {
    res.status(409).json({ error: "Event is already closed" });
    return;
  }
  res.status(201).json(ChargeEventResponse.parse(serializeAction(action)));
});

router.post("/events/:eventId/email", async (req, res): Promise<void> => {
  const params = EmailEventParams.safeParse(req.params);
  if (!params.success) {
    res.status(400).json({ error: params.error.message });
    return;
  }
  const body = EmailEventBody.safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.message });
    return;
  }
  const event = await getOpenEvent(params.data.eventId);
  if (!event) {
    res.status(404).json({ error: "Event not found" });
    return;
  }
  const [action] = await db
    .insert(eventActionsTable)
    .values({
      routeEventId: event.id,
      actionType: "email",
      isFinal: false,
      notes: `${body.data.toType}: ${body.data.to} — ${body.data.subject}${body.data.body ? ` — ${body.data.body}` : ""}`,
      createdBy: CURRENT_USER,
    })
    .returning();
  res.status(201).json(EmailEventResponse.parse(serializeAction(action!)));
});

router.post("/events/:eventId/close", async (req, res): Promise<void> => {
  const params = CloseEventParams.safeParse(req.params);
  if (!params.success) {
    res.status(400).json({ error: params.error.message });
    return;
  }
  const body = CloseEventBody.safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.message });
    return;
  }
  const event = await getOpenEvent(params.data.eventId);
  if (!event) {
    res.status(404).json({ error: "Event not found" });
    return;
  }

  // Validate duplicate IDs against the server-computed nearby set only
  const requestedDuplicates = [...new Set(body.data.duplicateEventIds ?? [])];
  let duplicateIds: number[] = [];
  if (requestedDuplicates.length > 0) {
    const nearby = await queryNearbyRows(event);
    const nearbySet = new Set(nearby.map((n) => n.id));
    duplicateIds = requestedDuplicates.filter((id) => nearbySet.has(id));
    if (duplicateIds.length !== requestedDuplicates.length) {
      res
        .status(400)
        .json({ error: "duplicateEventIds must be nearby overages of this event" });
      return;
    }
  }

  const result = await db.transaction(async (tx) => {
    // Conditionally close the main event; fail if it was closed concurrently
    const closedMain = await tx
      .update(routeEventsTable)
      .set({ eventStatus: 1, dateClosed: new Date(), closedBy: CURRENT_USER })
      .where(
        and(
          eq(routeEventsTable.id, event.id),
          eq(routeEventsTable.eventStatus, 0),
        ),
      )
      .returning({ id: routeEventsTable.id });
    if (closedMain.length === 0) return null;

    const [action] = await tx
      .insert(eventActionsTable)
      .values({
        routeEventId: event.id,
        actionType: "close",
        isFinal: true,
        closeReason: body.data.closeReason,
        notes: body.data.notes ?? null,
        createdBy: CURRENT_USER,
      })
      .returning();

    // Contract close: flag the account so its overages stop appearing
    if (body.data.closeReason === CONTRACT_CLOSE_REASON) {
      await tx
        .insert(accountFlagsTable)
        .values({
          districtId: event.districtId,
          accountNumber: event.accountNumber,
          flag: "contract_no_overages",
          createdBy: CURRENT_USER,
        })
        .onConflictDoNothing();
    }

    if (duplicateIds.length > 0) {
      const closedDupes = await tx
        .update(routeEventsTable)
        .set({ eventStatus: 1, dateClosed: new Date(), closedBy: CURRENT_USER })
        .where(
          and(
            inArray(routeEventsTable.id, duplicateIds),
            eq(routeEventsTable.eventStatus, 0),
          ),
        )
        .returning({ id: routeEventsTable.id });
      if (closedDupes.length > 0) {
        await tx.insert(eventActionsTable).values(
          closedDupes.map((d) => ({
            routeEventId: d.id,
            actionType: "close",
            isFinal: true,
            closeReason: "Duplicate",
            notes: `Closed as duplicate of event #${event.id}`,
            createdBy: CURRENT_USER,
          })),
        );
      }
    }
    return action!;
  });

  if (!result) {
    res.status(409).json({ error: "Event is already closed" });
    return;
  }
  res.status(201).json(CloseEventResponse.parse(serializeAction(result)));
});

router.post("/events/bulk-close", async (req, res): Promise<void> => {
  const body = BulkCloseEventsBody.safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.message });
    return;
  }
  const { closeReason, notes } = body.data;
  const eventIds = [...new Set(body.data.eventIds)];

  // All events must belong to a single district
  const targets = await db
    .select({
      id: routeEventsTable.id,
      districtId: routeEventsTable.districtId,
      accountNumber: routeEventsTable.accountNumber,
    })
    .from(routeEventsTable)
    .where(inArray(routeEventsTable.id, eventIds));
  const districts = new Set(targets.map((t) => t.districtId));
  if (districts.size > 1) {
    res
      .status(400)
      .json({ error: "All events must belong to the same district" });
    return;
  }

  const closed = await db.transaction(async (tx) => {
    const closedRows = await tx
      .update(routeEventsTable)
      .set({ eventStatus: 1, dateClosed: new Date(), closedBy: CURRENT_USER })
      .where(
        and(
          inArray(routeEventsTable.id, eventIds),
          eq(routeEventsTable.eventStatus, 0),
        ),
      )
      .returning({ id: routeEventsTable.id });
    if (closedRows.length > 0) {
      await tx.insert(eventActionsTable).values(
        closedRows.map((r) => ({
          routeEventId: r.id,
          actionType: "close",
          isFinal: true,
          closeReason,
          notes: notes ?? null,
          createdBy: CURRENT_USER,
        })),
      );

      // Contract close: flag each distinct account among the closed events
      if (closeReason === CONTRACT_CLOSE_REASON) {
        const closedIds = new Set(closedRows.map((r) => r.id));
        const flagged = new Map<
          string,
          { districtId: number; accountNumber: string }
        >();
        for (const t of targets) {
          if (closedIds.has(t.id)) {
            flagged.set(`${t.districtId}:${t.accountNumber}`, {
              districtId: t.districtId,
              accountNumber: t.accountNumber,
            });
          }
        }
        if (flagged.size > 0) {
          await tx
            .insert(accountFlagsTable)
            .values(
              [...flagged.values()].map((f) => ({
                districtId: f.districtId,
                accountNumber: f.accountNumber,
                flag: "contract_no_overages",
                createdBy: CURRENT_USER,
              })),
            )
            .onConflictDoNothing();
        }
      }
    }
    return closedRows.length;
  });

  res.json(
    BulkCloseEventsResponse.parse({
      closedCount: closed,
      skippedCount: eventIds.length - closed,
    }),
  );
});

export default router;
