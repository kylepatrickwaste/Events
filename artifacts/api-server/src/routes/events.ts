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
} from "@workspace/api-zod";

const router: IRouter = Router();

const CURRENT_USER = "Kyle.Patrick";

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
    createdBy: a.createdBy,
    dateCreated: a.dateCreated.toISOString(),
  };
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
      .where(eq(routeEventsTable.districtId, districtId));

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
      .where(eq(routeEventsTable.districtId, districtId));

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
      .where(eq(routeEventsTable.districtId, districtId))
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

  const conditions = [eq(routeEventsTable.districtId, districtId)];
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
  const [action] = await db
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
    await db
      .update(routeEventsTable)
      .set({ eventStatus: 1, dateClosed: new Date(), closedBy: CURRENT_USER })
      .where(eq(routeEventsTable.id, event.id));
  }
  res.status(201).json(ChargeEventResponse.parse(serializeAction(action!)));
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
  const [action] = await db
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
  await db
    .update(routeEventsTable)
    .set({ eventStatus: 1, dateClosed: new Date(), closedBy: CURRENT_USER })
    .where(eq(routeEventsTable.id, event.id));
  res.status(201).json(CloseEventResponse.parse(serializeAction(action!)));
});

export default router;
