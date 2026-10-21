// B5 sandbox: ASLI Bun routers (movein.ts / release.ts / revenue.ts, copy) ek chhote express server par — differential proof ke liye.
// Env: PORT, SUPABASE4_URL, SUPABASE4_SERVICE_ROLE_KEY, SELF_ORIGIN (release probes isi par jati hain).
import express from "express";
import revenuePublic, { founderRevenueRouter } from "./routes/revenue";
import releasePublic, { founderReleaseRouter, outboxRouter } from "./routes/release";
import { moveinRouter, moveinPublicRouter, founderMoveinRouter } from "./routes/movein";

const app = express();
app.use(express.json());
app.set("trust proxy", true);
app.get("/api/health", (_q, r) => r.json({ ok: true }));
app.get("/health", (_q, r) => r.json({ ok: true }));
app.use("/api/public", revenuePublic);
app.use("/api/public", releasePublic);
app.use("/api/public", moveinPublicRouter);
app.use("/api/movein", moveinRouter);
app.use("/api/founder", founderRevenueRouter);
app.use("/api/founder", founderReleaseRouter);
app.use("/api/founder", founderMoveinRouter);
app.use("/api/mail", outboxRouter);
// every other guarded route the QA run probes: login required
app.use("/api", (_q, r) => r.status(401).json({ error: "unauthorized" }));
app.listen(Number(process.env.PORT || 9931), "127.0.0.1", () => console.log("bun-harness up"));
