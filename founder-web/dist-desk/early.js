// Starts the browser kernel (WASM, in a Worker) the moment the page parses, in parallel with the main bundle download (page refresh speed).
// The worker file name is hashed, so the build writes it into <meta name="kernel-worker">; if that tag is missing the app starts the kernel itself (same result, a little later).
(function () {
  try {
    var m = document.querySelector('meta[name="kernel-worker"]'); if (!m) return;
    var tt = window.trustedTypes, href = new URL(m.content, location.href);
    if (href.origin !== location.origin || href.pathname.indexOf("/_cc/assets/") !== 0) return;
    var p = tt && tt.createPolicy ? tt.createPolicy("anexo-kernel-early", { createScriptURL: function (u) { return u; } }) : null;
    var w = new Worker(p ? p.createScriptURL(href.href) : href.href, { type: "module" });
    w.postMessage({ warm: true }); window.__kw = w;
  } catch (e) { /* the app falls back to starting the kernel itself */ }
})();
