/**
 * Poore app mein: jis bhi ek-line wali (left-right scroll hone wali) patti par mouse se pakad kar ghumao.
 * Touch par browser pehle se swipe deta hai; yeh sirf mouse ke liye hai.
 *
 * Kyun (20 Oct 2026, founder): mail list ke address chips / category tabs, mail kholne wali side ki buttons, settings tabs,
 * integrations tabs — sab sirf patli scrollbar se chalte the, baqi icons nazar nahi aate the. Pehle har patti par alag hook
 * tha; ab ek jagah (AppShell) se sab par, aur nayi patti khud-ba-khud shamil.
 *
 * Qaide:
 *  - Sirf wahi element jo asal mein chauda ho (scrollWidth > clientWidth) aur UPAR-NEECHE scroll na hota ho.
 *    Is liye lambi list / mail ka text pakadna (select karna) kabhi nahi chheenta.
 *  - input / textarea / select / contenteditable / [data-no-drag] par drag shuru nahi hota.
 *  - 5px se kam hilna = click (button chalta hai). Us se zyada = drag, aur uska click nigal liya jata hai.
 *  - Mail body sandboxed iframe mein hai, uske andar yeh chalta hi nahi.
 */
const THRESHOLD = 5;

function rowAt(start: EventTarget | null): HTMLElement | null {
  let el = start instanceof Element ? (start as HTMLElement) : null;
  while (el && el !== document.body && el !== document.documentElement) {
    if (el.matches("input, textarea, select, [contenteditable=''], [contenteditable='true'], [data-no-drag]")) return null;
    if (el.scrollWidth > el.clientWidth + 2 && el.scrollHeight <= el.clientHeight + 2) {
      const ox = getComputedStyle(el).overflowX;
      if (ox === "auto" || ox === "scroll") return el;
    }
    el = el.parentElement;
  }
  return null;
}

export function installDragScroll(): () => void {
  let row: HTMLElement | null = null;
  let moved = false;
  let startX = 0;
  let startLeft = 0;
  let pid = -1;

  const down = (e: PointerEvent) => {
    if (e.pointerType !== "mouse" || e.button !== 0) return;
    row = rowAt(e.target);
    if (!row) return;
    // patli scrollbar par seedha pakadna = browser ka apna thumb-drag; usse na ulajhna
    const r = row.getBoundingClientRect();
    if (e.clientY > r.top + row.clientHeight) {
      row = null;
      return;
    }
    moved = false;
    startX = e.clientX;
    startLeft = row.scrollLeft;
    pid = e.pointerId;
  };
  const move = (e: PointerEvent) => {
    if (!row) return;
    const dx = e.clientX - startX;
    if (!moved && Math.abs(dx) < THRESHOLD) return;
    if (!moved) {
      moved = true;
      try {
        row.setPointerCapture(pid);
      } catch {
        /* koi baat nahi */
      }
      row.style.cursor = "grabbing";
      row.style.userSelect = "none";
    }
    row.scrollLeft = startLeft - dx;
  };
  const end = () => {
    if (!row) return;
    row.style.cursor = "";
    row.style.userSelect = "";
    try {
      row.releasePointerCapture(pid);
    } catch {
      /* koi baat nahi */
    }
    row = null;
    // click is pointerup ke foran baad aata hai — usay nigalne ke liye moved thodi der rakho
    if (moved) window.setTimeout(() => (moved = false), 0);
  };
  const click = (e: MouseEvent) => {
    if (moved) {
      e.preventDefault();
      e.stopPropagation();
      moved = false;
    }
  };

  // Chrome pakad kar khinchne par apna native drag-and-drop (dragstart) ya text-select shuru kar deta hai, jo hamare
  // drag ko pointercancel kar deta hai (live test: category row sirf ~9px hil kar ruk jati thi). Row ke andar rok do.
  const stopNative = (e: Event) => {
    if (row) e.preventDefault();
  };

  document.addEventListener("dragstart", stopNative, true);
  document.addEventListener("selectstart", stopNative, true);
  document.addEventListener("pointerdown", down, true);
  document.addEventListener("pointermove", move, true);
  document.addEventListener("pointerup", end, true);
  document.addEventListener("pointercancel", end, true);
  document.addEventListener("click", click, true);
  return () => {
    document.removeEventListener("dragstart", stopNative, true);
    document.removeEventListener("selectstart", stopNative, true);
    document.removeEventListener("pointerdown", down, true);
    document.removeEventListener("pointermove", move, true);
    document.removeEventListener("pointerup", end, true);
    document.removeEventListener("pointercancel", end, true);
    document.removeEventListener("click", click, true);
  };
}
