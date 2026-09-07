/**
 * ANEXOVIDEOCALL · PHASE 31A — PRE-WARMED ICE (ring se tasveer tak aadha waqt)
 *
 * FOUNDER LOCK:
 *   - Call button dabne se PEHLE hi ek idle RTCPeerConnection candidates gather
 *     karti hai (STUN + apna coturn). Media isse guzarti nahi — sirf network
 *     raasta pehle se maloom ho jata hai.
 *   - Har reading asli hai: kitne candidates, pehla candidate kitni der mein,
 *     gather mukammal hua ya nahi. Na mile to null — guess kabhi nahi.
 *   - Warm socket 60s baad khud band ho jata hai (battery aur CPU ka ehtiram).
 *   - Yeh koi jhooti "instant call" claim nahi banati — sirf waqt bachati hai.
 */

export type PrewarmReport = {
  started_at_ms: number;
  /** Pehla ICE candidate kitni ms mein mila (asli reading). */
  first_candidate_ms: number | null;
  /** Gather mukammal hone tak ka waqt. */
  gather_ms: number | null;
  candidates: number;
  relay_candidates: number;
  /** coturn se relay candidate mila ya nahi — badge ka sach isi se. */
  relay_ready: boolean;
  complete: boolean;
};

let warm: {
  pc: RTCPeerConnection;
  report: PrewarmReport;
  timer: number;
} | null = null;

/** Abhi tak ki asli reading (call start ke waqt DB mein jati hai). */
export function prewarmReport(): PrewarmReport | null {
  return warm?.report ?? null;
}

/**
 * Idle gather shuru. Dobara call karna safe hai — ek hi warm socket rehta hai.
 * `iceServers` wahi jo `iceBundle()` deta hai (TURN creds server se).
 */
export function prewarmIce(iceServers: RTCIceServer[]): PrewarmReport {
  if (warm) return warm.report;

  const started = Date.now();
  const report: PrewarmReport = {
    started_at_ms: started,
    first_candidate_ms: null,
    gather_ms: null,
    candidates: 0,
    relay_candidates: 0,
    relay_ready: false,
    complete: false,
  };

  const pc = new RTCPeerConnection({
    iceServers,
    iceCandidatePoolSize: 4,
    bundlePolicy: "max-bundle",
  });

  pc.onicecandidate = (e) => {
    if (!e.candidate) {
      report.complete = true;
      report.gather_ms = Date.now() - started;
      return;
    }
    report.candidates += 1;
    if (report.first_candidate_ms == null) report.first_candidate_ms = Date.now() - started;
    if (e.candidate.type === "relay") {
      report.relay_candidates += 1;
      report.relay_ready = true;
    }
  };

  // Data channel = gather trigger, koi media nahi (camera off rehti hai).
  pc.createDataChannel("ax-prewarm");
  void pc
    .createOffer({ offerToReceiveAudio: true, offerToReceiveVideo: true })
    .then((offer) => pc.setLocalDescription(offer))
    .catch(() => {
      /* gather na ho to call phir bhi normal chalti hai */
    });

  const timer = window.setTimeout(() => dropPrewarm(), 60_000);
  warm = { pc, report, timer };
  return report;
}

/** Warm socket band — call live hone par ya 60s baad. */
export function dropPrewarm() {
  if (!warm) return;
  window.clearTimeout(warm.timer);
  try {
    warm.pc.close();
  } catch {
    /* already closed */
  }
  warm = null;
}
