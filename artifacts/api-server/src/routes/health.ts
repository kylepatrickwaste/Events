import { Router, type IRouter } from "express";
import { HealthCheckResponse } from "@workspace/api-zod";
import { readBuildNumber } from "../lib/build-info";

const router: IRouter = Router();

router.get("/healthz", (_req, res) => {
  const data = HealthCheckResponse.parse({
    status: "ok",
    buildNumber: readBuildNumber(),
  });
  res.json(data);
});

export default router;
