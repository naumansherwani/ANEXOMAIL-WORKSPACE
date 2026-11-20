// QC2-B: the rich compose box. Tiptap 3 on a RESTRICTED schema = browser wall 1 (the server's ammonia clean is wall 2 and decides). Only what the server keeps can exist here:
// bold, italic, underline, inline code, link (https / mailto), bullet + numbered list, quote, line break (the same set the server keeps). No images, no headings, no colours, no fonts: Word / web paste loses them by construction.
import { forwardRef, useImperativeHandle, useState } from "react";
import { EditorContent, useEditor, type Editor } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import { htmlIsEmpty } from "./rich_pure";
import "./richeditor.css";

export type RichHandle = { insertHtml: (html: string) => void; insertText: (t: string) => void; focus: () => void; replaceSlash: (typed: string, html: string) => void };

/** The plain text twin of the editor's HTML (the server needs one): blocks separated by a blank line, list marks, links written out as "text (https://...)". */
export function htmlToPlain(html: string): string {
  const d = new DOMParser().parseFromString(`<body>${html}</body>`, "text/html");
  const walk = (n: Node): string => {
    if (n.nodeType === 3) return n.textContent ?? "";
    if (!(n instanceof HTMLElement)) return "";
    const tag = n.tagName.toLowerCase(), kids = () => [...n.childNodes].map(walk).join("");
    if (tag === "br") return "\n";
    if (tag === "a") { const h = n.getAttribute("href") ?? "", t = kids(); return h && t.trim() !== h && h !== `mailto:${t.trim()}` ? `${t} (${h})` : t; }
    if (tag === "ul" || tag === "ol") { let i = 0; return [...n.children].map((li) => { i++; return `${tag === "ol" ? `${i}. ` : "- "}${walk(li).trim()}`; }).join("\n") + "\n\n"; }
    if (tag === "blockquote") return kids().trim().split("\n").map((l) => `> ${l}`).join("\n") + "\n\n";
    if (tag === "p" || tag === "div") return kids().replace(/\s+$/, "") + "\n\n";
    return kids();
  };
  return walk(d.body).replace(/\n{3,}/g, "\n\n").trim();
}

type P = { initialHtml: string; onChange: (html: string, text: string) => void; placeholder?: string; label: string; onSlash?: (typed: string | null) => void };
export const RichEditor = forwardRef<RichHandle, P>(function RichEditor({ initialHtml, onChange, placeholder, label, onSlash }, ref) {
  const editor = useEditor({
    immediatelyRender: true,
    content: initialHtml || "<p></p>",
    extensions: [StarterKit.configure({
      heading: false, horizontalRule: false, strike: false,
      link: { openOnClick: false, autolink: true, linkOnPaste: true, protocols: ["https", "mailto"], defaultProtocol: "https", HTMLAttributes: { rel: "noopener noreferrer nofollow" } },
    })],
    editorProps: {
      attributes: { id: "mc-rich", class: "mc-t mc-rich", role: "textbox", "aria-multiline": "true", "aria-label": label, "data-placeholder": placeholder ?? "" },
      // the schema already drops every unknown tag, style and image from a paste; pasted or dropped FILES are refused outright
      handlePaste: (_v, e) => !!e.clipboardData?.files?.length,
      handleDrop: (_v, e) => !!(e as DragEvent).dataTransfer?.files?.length,
    },
    onUpdate: ({ editor: ed }) => {
      const h = ed.getHTML(), empty = htmlIsEmpty(h); onChange(empty ? "" : h, empty ? "" : htmlToPlain(h));
      if (onSlash) { const { $from } = ed.state.selection; const before = $from.parent.textBetween(0, $from.parentOffset, "\n", "\0"); const m = /(?:^|\s)\/([a-z0-9_-]{0,40})$/.exec(before); onSlash(m ? m[1] : null); }
    },
  });
  useImperativeHandle(ref, () => ({
    insertHtml: (html) => { editor?.chain().focus().insertContent(html).run(); },
    insertText: (t) => { editor?.chain().focus().insertContent(t).run(); },
    focus: () => { editor?.commands.focus("end"); },
    // "/thanks" typed at the caret is replaced by the snippet (its text -> html is made by the caller)
    replaceSlash: (typed, html) => { if (!editor) return; const to = editor.state.selection.from, from = to - (typed.length + 1); editor.chain().focus().deleteRange({ from, to }).insertContent(html).run(); },
  }), [editor]);
  if (!editor) return null;
  const B = (k: string, name: string, active: boolean, run: () => void, txt: string, cls = "") => (
    <button type="button" key={k} className={`rt-b ${cls}`} aria-pressed={active} aria-label={name} title={name} onMouseDown={(e) => e.preventDefault()} onClick={run}>{txt}</button>
  );
  return (
    <div className="rt">
      <div className="rt-bar" role="toolbar" aria-label="Formatting">
        {B("b", "Bold", editor.isActive("bold"), () => editor.chain().focus().toggleBold().run(), "B", "rt-bold")}
        {B("i", "Italic", editor.isActive("italic"), () => editor.chain().focus().toggleItalic().run(), "I", "rt-it")}
        {B("u", "Underline", editor.isActive("underline"), () => editor.chain().focus().toggleUnderline().run(), "U", "rt-un")}
        {B("ul", "Bulleted list", editor.isActive("bulletList"), () => editor.chain().focus().toggleBulletList().run(), "•")}
        {B("ol", "Numbered list", editor.isActive("orderedList"), () => editor.chain().focus().toggleOrderedList().run(), "1.")}
        {B("c", "Code", editor.isActive("code"), () => editor.chain().focus().toggleCode().run(), "</>")}
        {B("q", "Quote", editor.isActive("blockquote"), () => editor.chain().focus().toggleBlockquote().run(), "❝")}
        <LinkButton editor={editor} />
      </div>
      <EditorContent editor={editor} />
    </div>
  );
});

/** Link without browser dialogs: a small inline field (https or mailto only; anything else is refused here and removed again by the server). */
function LinkButton({ editor }: { editor: Editor }) {
  const [open, setOpen] = useState(false), [v, setV] = useState(""), [bad, setBad] = useState(false);
  const apply = () => {
    const t = v.trim(); if (!t) { editor.chain().focus().unsetLink().run(); setOpen(false); return; }
    const href = /^(https:\/\/|mailto:)/i.test(t) ? t : /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(t) ? `mailto:${t}` : `https://${t.replace(/^http:\/\//i, "")}`;
    try { const u = new URL(href); if (u.protocol !== "https:" && u.protocol !== "mailto:") throw new Error("scheme"); } catch { setBad(true); return; }
    editor.chain().focus().extendMarkRange("link").setLink({ href }).run(); setOpen(false); setBad(false); setV("");
  };
  return (<>
    <button type="button" className="rt-b" aria-pressed={editor.isActive("link")} aria-label="Link" title="Link" onMouseDown={(e) => e.preventDefault()} onClick={() => { setV((editor.getAttributes("link").href as string) ?? ""); setOpen(!open); setBad(false); }}>🔗</button>
    {open && <span className="rt-link"><input value={v} onChange={(e) => setV(e.target.value)} placeholder="https://… or name@host" aria-label="Link address" aria-invalid={bad} autoFocus onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); e.stopPropagation(); apply(); } if (e.key === "Escape") { e.stopPropagation(); setOpen(false); } }} /><button type="button" className="rt-b rt-ok" onClick={apply}>OK</button>{bad && <span className="mx-warn" role="alert">Only https or mailto links.</span>}</span>}
  </>);
}
