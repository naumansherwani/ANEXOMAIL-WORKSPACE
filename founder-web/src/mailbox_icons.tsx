// QUI-LIVE: ONE icon set for the mailbox. 24 grid, 1.5 stroke, round caps, the same optical size everywhere. Active state is carried by the button (colour + a duotone fill), not by a second icon.
const P: Record<string, string> = {
  mail: "M4 6.5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1zM3.5 7.5l8.5 6 8.5-6",
  inbox: "M3.5 13.5h5l1.2 2.5h4.6l1.2-2.5h5M3.5 13.5L6 6.5h12l2.5 7v5.5a1 1 0 0 1-1 1h-15a1 1 0 0 1-1-1z",
  star: "M12 3.8l2.4 5 5.4.7-4 3.8 1 5.4-4.8-2.6-4.8 2.6 1-5.4-4-3.8 5.4-.7z",
  send: "M20.5 3.5L10 14M20.5 3.5l-6.5 17-3.5-7.5-7-3.5z",
  draft: "M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17zM14.5 7.5l3 3",
  outbox: "M12 15V4M8 8l4-4 4 4M4.5 15v3.5a1 1 0 0 0 1 1h13a1 1 0 0 0 1-1V15",
  archive: "M3.5 5.5h17v4h-17zM5 9.5v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-9M10 13h4",
  snooze: "M12 7.5V12l3 2M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17z",
  spam: "M12 3.8l9 15.7H3zM12 10v4.2M12 17h.01",
  shield: "M12 3.5l7.5 2.7v5.6c0 4.3-3 7.6-7.5 8.7-4.5-1.1-7.5-4.4-7.5-8.7V6.2zM9 12l2.2 2.2L15.2 10",
  vault: "M5 4.5h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-13a1 1 0 0 1 1-1zM12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7zM15.5 12H18",
  trash: "M4.5 7h15M9.5 7V4.5h5V7M6.5 7l.9 12.5h9.2L17.5 7M10 11v5M14 11v5",
  lock: "M7 11V8a5 5 0 0 1 10 0v3M5.5 11h13v9h-13z",
  pen: "M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17zM14.5 7.5l3 3",
  clip: "M19.5 11.5l-7.8 7.8a4.6 4.6 0 0 1-6.5-6.5l8.4-8.4a3.1 3.1 0 0 1 4.4 4.4l-8.3 8.3a1.5 1.5 0 0 1-2.2-2.2l7.6-7.6",
  reply: "M9.5 6L4 11.5 9.5 17M4 11.5h9a6.5 6.5 0 0 1 6.5 6.5v1",
  flag: "M5.5 20.5V4M5.5 5h11l-2 4 2 4h-11",
  unread: "M3.5 7.5h17v10h-17zM3.5 7.5l8.5 6 8.5-6",
  back: "M15 5.5L8.5 12 15 18.5",
  close: "M6 6l12 12M18 6L6 18",
  search: "M10.5 17.5a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20.5 20.5l-5-5",
  spark: "M12 3.5l1.7 5.3 5.3 1.7-5.3 1.7L12 17.5l-1.7-5.3L5 10.5l5.3-1.7zM18.5 16.5l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z",
  moon: "M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z",
  sun: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4",
  gauge: "M4.5 17a8 8 0 1 1 15 0M12 13.5l3-4.5",
  more: "M5 12h.01M12 12h.01M19 12h.01",
  check: "M5 12.5l4.2 4.2L19 7",
  pin: "M9 4.5h6l-1 5.5 3 3H7l3-3zM12 13v7",
  list: "M4 7h16M4 12h16M4 17h16",
};
export function Ic({ k, s = 20, fill = false }: { k: keyof typeof P | string; s?: number; fill?: boolean }) {
  return <svg className="mbx-ic" width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{fill && <path d={P[k] ?? P.mail} fill="currentColor" fillOpacity=".16" stroke="none" />}<path d={P[k] ?? P.mail} /></svg>;
}
export const FOLDER_ICON: Record<string, string> = { inbox: "inbox", sent: "send", drafts: "draft", outbox: "outbox", archive: "archive", snoozed: "snooze", spam: "spam", quarantine: "shield", vault: "vault", trash: "trash" };
