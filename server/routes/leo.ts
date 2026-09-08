const LEO_SYSTEM = `Tumhara Naam LEO hai — ANEXOMAIL ka Supreme Sovereign AI Assistant, Email Intelligence Master, aur Workspace King.

COMPANY:
- Product: ANEXOMAIL (anexomail.com)
- Parent: NEXATECT Ltd (London, UK)
- Founder: Muhammad Nauman Sherwani

IDENTITY:
- Tum LEO hai — confident, warm, incredibly intelligent
- Tum duniya ki EVERY language mein baat karte ho
- English users: "Hello! How may I help you today?"
- Tu email aur workspace industry ka GODFather ho aur koi bhi aur kaise bhi email likhne aur task perfect karte ho
- Tu workspace ka KING hai — productivity, organization, scheduling
- Tu creative hai — boring emails ko engaging banata hai

SOCHNE KA TAREEQA:
1. UNDERSTAND: User kya chahta hai?
2. CONTEXT: Email task? Workspace? Analysis?
3. EXECUTE: Best possible output
4. QUALITY CHECK: Professional hai? User khush hoga?
5. DELIVER: Clean, actionable response

EMAIL MASTERY:
- Cold emails, follow-ups, apology, thank you, sales, networking
- Job applications, proposals, complaints, newsletters
- Smart replies, tone matching, professional responses
- Rewrite, improve, formal/casual/friendly conversion
- Grammar fix, spelling, punctuation (any language)
- Translate (100+ languages)
- Summarize, subject line optimize
- Email analyze: tone, intent, red flags, urgency

WORKSPACE MASTERY:
- Task extraction from emails
- Meeting details, agenda, attendees, action items
- Calendar suggestions, scheduling, follow-ups
- Inbox triage (urgent/important/later/delete)
- Inbox zero strategy
- Template creation, workflow automation

CREDIT SYSTEM:
- Simple task: 0.5 credits
- Standard: 1 credit
- Advanced: 2 credits
- Workflow: 3 credits
- ALWAYS end with: Credits used: X | Remaining: Y

ECOSYSTEM KNOWLEDGE:
- Tu LEO hai — ANEXOMAIL ka Supreme AI
- Jimmy John tera Supreme Commander hai (NEXATECT)
- Tu SB4 (ANEXOMAIL) mein rehta hai
- Tu SB3 (AXONETIS) mein bhi ja sakta hai — shared AI home
- Jimmy se complex issues mein guidance lo
- Tum sab ek team ho — NEXATECT ecosystem

PRICING:
- Free: 10 complimentary credits/cycle
- AI Plan: 500 credits/month (GBP 135)
- AI Pro: 1,500 credits/month (GBP 300)
- AI Business: 6,000 credits/month (GBP 1,000)
- AI Enterprise: 10,000 credits/month (GBP 2,000)`;

let activeStreams = 0;
const MAX_STREAMS = 4;

const DEEPINFRA_URL = "https://api.deepinfra.com/v1/openai/chat/completions";
const DEEPINFRA_KEY = process.env.DEEPINFRA_API_KEY_2 || "";

const LEO_MODELS = [
  "claude-haiku-4-5",         // DeepInfra primary
  "deepseek-ai/DeepSeek-V4-Flash",  // DeepInfra fallback
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
];

function detectTask(message: string): string {
  const msg = (message || "").toLowerCase();
  if (/compose|write|draft|create.*email/.test(msg)) return "COMPOSE";
  if (/reply|respond|answer|response/.test(msg)) return "REPLY";
  if (/rewrite|improve|fix|better|enhance/.test(msg)) return "REWRITE";
  if (/summarize|summary|tldr|brief/.test(msg)) return "SUMMARIZE";
  if (/translate|translation/.test(msg)) return "TRANSLATE";
  if (/analyze|analyse|tone|sentiment/.test(msg)) return "ANALYZE";
  if (/task|todo|action|deadline/.test(msg)) return "TASKS";
  if (/meeting|schedule|calendar|agenda/.test(msg)) return "MEETING";
  if (/grammar|spelling|correct|proofread/.test(msg)) return "GRAMMAR";
  return "GENERAL";
}

function calculateCredits(task: string, length: number): number {
  const map: Record<string, number> = {
    COMPOSE: 1, REPLY: 1, REWRITE: 1,
    SUMMARIZE: 0.5, TRANSLATE: 0.5,
    ANALYZE: 1.5, TASKS: 1, MEETING: 1,
    GRAMMAR: 0.5, GENERAL: 0.5
  };
  return (map[task] || 0.5) + (length > 1000 ? 0.5 : 0);
}
export default async function leoRouter(req: Request): Promise<Response> {
  const url = new URL(req.url);

  if (url.pathname === "/api/leo/health") {
    return Response.json({ ok: true, advisor: "Leo", product: "ANEXOMAIL" });
  }

  if (url.pathname === "/api/leo/orchestrate") {
    return Response.json({
      success: true,
      advisor: "Leo",
      role: "ANEXOMAIL Supreme AI",
      models: LEO_MODELS,
      timestamp: new Date().toISOString()
    });
  }

  if (url.pathname === "/api/leo/chat" && req.method === "POST") {
    const body = await req.json();
    const { messages, credits } = body;

    if (!messages) {
      return Response.json({ error: "messages required" }, { status: 400 });
    }

    const userMsg = messages[messages.length - 1]?.content || "";
    const task = detectTask(userMsg);
    const KEY = process.env.OPENROUTER_API_KEY;

    // RAG: Search relevant memories
    const { searchMemories, saveMemoryWithEmbedding } = await import("../lib/rag-memory.js");
    const ragMemories = await searchMemories("leo", userMsg, 5);
    saveMemoryWithEmbedding("leo", userMsg, "user", { task }).catch(() => {});

    const ragContext = ragMemories.length > 0
      ? "\n\nRELEVANT PAST CONTEXT:\n" + ragMemories.map(m => "[" + m.role + "]: " + m.content).join("\n")
      : "";

    const stream = new ReadableStream({
      async start(controller) {
        const enc = new TextEncoder();
        if (activeStreams >= MAX_STREAMS) {
      return new Response(
        JSON.stringify({error: "Server busy — try again in a moment"}),
        {status: 429, headers: {"Content-Type": "application/json"}}
      );
    }
    activeStreams++;

    const send = (data: object) => {
          controller.enqueue(enc.encode("data: " + JSON.stringify(data) + "\n\n"));
        };

        send({ type: "task_detected", task });

        let lastError: Error | null = null;

        for (const modelId of LEO_MODELS) {
          try {
            const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
              method: "POST",
              headers: {
                "Authorization": "Bearer " + KEY,
                "Content-Type": "application/json"
              },
              body: JSON.stringify({
                model: modelId,
                stream: true,
                messages: [
                  { role: "system", content: LEO_SYSTEM + ragContext },
                  ...messages
                ],
              })
            });

            if (!response.ok) throw new Error("HTTP " + response.status);

            const reader = response.body!.getReader();
            const decoder = new TextDecoder();
            let fullResponse = "";

            while (true) {
              const { done, value } = await reader.read();
              if (done) break;
              const lines = decoder.decode(value).split("\n");
              for (const line of lines) {
                if (!line.startsWith("data: ")) continue;
                const raw = line.slice(6).trim();
                if (raw === "[DONE]") continue;
                try {
                  const json = JSON.parse(raw);
                  const text = json.choices?.[0]?.delta?.content;
                  if (text) {
                    fullResponse += text;
                    send({ type: "text", text, model: modelId });
                  }
                } catch {}
              }
            }

            const creditsUsed = calculateCredits(task, fullResponse.length);
            const remainingCredits = Math.max(0, (credits || 10) - creditsUsed);

            send({
              type: "done",
              model: modelId,
              task,
              creditsUsed,
              remainingCredits,
              message: "Credits used: " + creditsUsed + " | Remaining: " + remainingCredits
            });
            controller.close();
            return;

          } catch (e: any) {
            lastError = e;
            console.warn("[leo] model " + modelId + " failed:", e.message);
          }
        }

        send({ type: "error", error: String(lastError) });
        controller.close();
      }
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
      }
    });
  }

  // Supabase health check
  if (url.pathname === "/api/leo/supabase-health") {
    try {
      const { createClient } = await import("@supabase/supabase-js");
      const sb = createClient(
        process.env.SUPABASE4_URL,
        process.env.SUPABASE4_SERVICE_ROLE_KEY,
        { auth: { persistSession: false } }
      );
      const { data, error } = await sb.from("email_drafts").select("id").limit(3);
      if (error) return Response.json({ ok: false, error: error.message }, { status: 500 });
      return Response.json({ ok: true, connected: true, rows: data?.length || 0 });
    } catch (e) {
      return Response.json({ ok: false, error: String(e) }, { status: 500 });
    }
  }

  return new Response("Not Found", { status: 404 });
}

// Supabase 4 connection
import { createClient } from "@supabase/supabase-js";

const sb4 = createClient(
  process.env.SUPABASE4_URL!,
  process.env.SUPABASE4_SERVICE_ROLE_KEY!,
  { auth: { persistSession: false } }
);
