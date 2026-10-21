// B5 sandbox ONLY: real `express` yahan install nahi ho sakta (network band), isliye itna hi chhota shim jitna Brain ke teen routers istemal karte hain
// (Router.get/post, req.headers/body/params/ip, res.status/json/setHeader/write/end). Routes ka apna code ek akshar nahi badla.
function compile(path) {
  const keys = [];
  const re = new RegExp("^" + path.replace(/\/+$/, "").replace(/:([A-Za-z_]+)/g, (_m, k) => { keys.push(k); return "([^/]+)"; }) + "/?$");
  return { re, keys };
}
class Router {
  constructor() { this.routes = []; }
  add(method, path, handlers) { const c = compile(path); this.routes.push({ method, ...c, handlers: handlers.flat() }); return this; }
  get(p, ...h) { return this.add("GET", p, h); }
  post(p, ...h) { return this.add("POST", p, h); }
  mount(prefix, router) { for (const r of router.routes) { const c = compile(prefix + r.src); this.routes.push({ ...r, ...c }); } }
  use(a, b) {
    const prefix = typeof a === "string" ? a : "";
    const r = typeof a === "string" ? b : a;
    if (typeof r === "function" && !(r instanceof Router)) { this.routes.push({ method: "*", re: new RegExp("^" + prefix), keys: [], handlers: [r], fallback: true }); return this; }
    for (const x of r.routes) {
      const src = prefix + (x.src || "");
      const c = compile(src);
      this.routes.push({ ...x, src, re: c.re, keys: c.keys });
    }
    return this;
  }
}
for (const m of ["get", "post"]) {
  const orig = Router.prototype[m];
  Router.prototype[m] = function (p, ...h) { orig.call(this, p, ...h); this.routes[this.routes.length - 1].src = p; return this; };
}
function express() {
  const app = new Router();
  app.settings = {};
  app.set = (k, v) => { app.settings[k] = v; };
  app.listen = (port, host, cb) => {
    Bun.serve({
      port, hostname: host,
      async fetch(request, server) {
        const url = new URL(request.url);
        const headers = {}; request.headers.forEach((v, k) => { headers[k.toLowerCase()] = v; });
        let body; const txt = request.method === "POST" ? await request.text() : "";
        try { body = txt ? JSON.parse(txt) : undefined; } catch { body = undefined; }
        const ip = (server.requestIP(request) || {}).address || "";
        const req = { method: request.method, headers, body, params: {}, query: Object.fromEntries(url.searchParams), ip, path: url.pathname };
        let status = 200; let isDone = false; const rh = { "content-type": "application/json" }; let out = ""; let done;
        const finished = new Promise((r) => (done = () => { isDone = true; r(); }));
        const res = {
          status(c) { status = c; return res; }, setHeader(k, v) { rh[k.toLowerCase()] = v; }, json(o) { out = JSON.stringify(o); done(); return res; },
          write(s) { out += s; return true; }, end() { done(); }, send(s) { out = String(s); done(); },
        };
        for (const r of app.routes) {
          if (r.fallback) { if (!r.re.test(url.pathname)) continue; }
          else if (r.method !== request.method) continue;
          const m = r.re.exec(url.pathname);
          if (!m) continue;
          (r.keys || []).forEach((k, i) => (req.params[k] = decodeURIComponent(m[i + 1])));
          for (const h of r.handlers) { await h(req, res, () => {}); }
          if (r.fallback && !isDone) continue;
          await Promise.race([finished, new Promise((r) => setTimeout(r, 60000))]);
          return new Response(out, { status, headers: rh });
        }
        return new Response(JSON.stringify({ error: "not_found" }), { status: 404, headers: rh });
      },
    });
    cb && cb();
  };
  return app;
}
express.Router = () => new Router();
express.json = () => () => {};
module.exports = express;
module.exports.Router = () => new Router();
module.exports.default = express;
