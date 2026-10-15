import { discoverBooks, runMonitor, saveSubscription, type MonitorEnv } from "./monitor";

interface Env extends MonitorEnv {
  OPENAI_API_KEY: string;
  CLIENT_TOKEN: string;
  OPENAI_MODEL: string;
  MAX_RECAPS_PER_DAY: string;
  MAX_RECAPS_PER_MONTH: string;
  MAX_INPUT_CHARACTERS: string;
  MAX_OUTPUT_TOKENS: string;
  RECAP_USAGE: KVNamespace;
}

interface RecapBook {
  title: string;
  position?: number | null;
  rating?: number | null;
  review?: string | null;
  finishedReadingAt?: string | null;
}

interface RecapRequest {
  seriesName: string;
  readBooks: RecapBook[];
  sourceFingerprint: string;
  recapType: "series" | "book";
}

interface Usage {
  day: string;
  dayCount: number;
  month: string;
  monthCount: number;
}

interface OpenAIResponse {
  status?: string;
  incomplete_details?: {
    reason?: string;
  };
  output?: Array<{
    type?: string;
    content?: Array<{
      type?: string;
      text?: string;
      annotations?: Array<{
        type?: string;
        url?: string;
        title?: string;
      }>;
    }>;
  }>;
}

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
const USAGE_KEY = "personal-recap-usage";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (path === "/v1/monitor/subscriptions" && request.method === "PUT") {
      if (!authorized(request, env.CLIENT_TOKEN)) return json({ error: "Unauthorized" }, 401);
      return saveSubscription(request, env);
    }
    if (path === "/v1/monitor/discoveries" && request.method === "POST") {
      if (!authorized(request, env.CLIENT_TOKEN)) return json({ error: "Unauthorized" }, 401);
      return discoverBooks(request, env);
    }
    if (request.method !== "POST" || path !== "/v1/recaps") {
      return json({ error: "Not found" }, 404);
    }
    if (!authorized(request, env.CLIENT_TOKEN)) {
      return json({ error: "Unauthorized" }, 401);
    }

    let payload: unknown;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "Request body must be JSON." }, 400);
    }
    const recapRequest = validate(payload, integer(env.MAX_INPUT_CHARACTERS, 20_000));
    if (recapRequest instanceof Response) return recapRequest;

    const quota = await checkQuota(env, integer(env.MAX_RECAPS_PER_DAY, 20), integer(env.MAX_RECAPS_PER_MONTH, 100));
    if (quota instanceof Response) return quota;

    const maxOutputTokens = recapOutputBudget(recapRequest, integer(env.MAX_OUTPUT_TOKENS, 6_600));
    let response: Response;
    let usedWebSearch = true;
    try {
      response = await requestOpenAI(env, recapRequest, true);
      // Web search has a separate rate limit from ordinary model generation.
      // When it is unavailable, retain a useful detailed recap instead of
      // making the reader wait on a service they do not control.
      if (response.status === 429) {
        response = await requestOpenAI(env, recapRequest, false);
        usedWebSearch = false;
      }
    } catch {
      console.error("OpenAI recap request could not reach the provider");
      return json({ error: "Recap generation is temporarily unavailable.", code: "provider_network_error" }, 502);
    }

    if (!response.ok) {
      // Do not log provider bodies: they may include reader-supplied content.
      console.error("OpenAI recap request failed", response.status);
      if (response.status === 429) {
        const providerFailure = await response.json().catch(() => null) as { error?: { code?: string; type?: string } } | null;
        const providerCode = providerFailure?.error?.code ?? providerFailure?.error?.type ?? "unknown";
        console.error("OpenAI recap research rate limited", providerCode);
        return json({ error: "The recap research service is temporarily busy. Please try again in a minute.", code: `provider_rate_limited_${providerCode}` }, 429);
      }
      return json({ error: "Recap generation is temporarily unavailable.", code: `openai_${response.status}` }, 502);
    }
    let result = await response.json() as OpenAIResponse;
    // A response that stops at the output limit is not a usable recap. Make
    // one compact rewrite attempt rather than saving text that ends mid-sentence.
    if (wasCutOff(result)) {
      let retry: Response;
      try {
        retry = await requestOpenAI(env, recapRequest, usedWebSearch, maxOutputTokens, true);
        if (retry.status === 429 && usedWebSearch) {
          retry = await requestOpenAI(env, recapRequest, false, maxOutputTokens, true);
        }
      } catch {
        return json({ error: "Recap generation is temporarily unavailable.", code: "provider_network_error" }, 502);
      }
      if (!retry.ok) {
        return json({ error: "The recap could not be completed. Please try again.", code: "incomplete_recap_retry_failed" }, 502);
      }
      result = await retry.json() as OpenAIResponse;
      if (wasCutOff(result)) {
        return json({ error: "The recap was too long to complete. Please try again.", code: "incomplete_recap" }, 502);
      }
    }
    const recap = outputText(result).trim();
    if (!recap) return json({ error: "Recap generation returned no text.", code: "empty_openai_response" }, 502);
    await recordQuota(env, quota);
    return json({ content: recapWithSources(result, recap), sourceFingerprint: recapRequest.sourceFingerprint });
  },
  async scheduled(_: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> { ctx.waitUntil(runMonitor(env)); }
};

function requestOpenAI(
  env: Env,
  recapRequest: RecapRequest,
  useWebSearch: boolean,
  maxOutputTokens = recapOutputBudget(recapRequest, integer(env.MAX_OUTPUT_TOKENS, 6_600)),
  compact = false
): Promise<Response> {
  const researchInstructions = recapInstructions(recapRequest.recapType, useWebSearch, compact);
  return fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      // GPT-5.5 is the supported model selected specifically for hosted web
      // search. Keep the existing configured model for the no-search fallback.
      model: useWebSearch ? "gpt-5.5" : env.OPENAI_MODEL,
      store: false,
      max_output_tokens: maxOutputTokens,
      // A recap is a short synthesis. Disabling reasoning prevents the
      // visible response budget from being spent on internal reasoning.
      reasoning: { effort: "none" },
      ...(useWebSearch ? {
        // Medium is the balanced search context: enough material for a detailed
        // recap without the latency of a full high-context research pass.
        tools: [{ type: "web_search", search_context_size: "medium" }],
        tool_choice: "required"
      } : {}),
      instructions: researchInstructions,
      input: recapPrompt(recapRequest)
    })
  });
}

function authorized(request: Request, token: string): boolean {
  const authorization = request.headers.get("authorization");
  return authorization === `Bearer ${token}`;
}

function validate(payload: unknown, maximumCharacters: number): RecapRequest | Response {
  if (!isRecord(payload) || typeof payload.seriesName !== "string" || !Array.isArray(payload.readBooks) || typeof payload.sourceFingerprint !== "string") {
    return json({ error: "seriesName, readBooks, and sourceFingerprint are required." }, 400);
  }
  if (!payload.seriesName.trim() || payload.readBooks.length === 0 || payload.readBooks.length > 50) {
    return json({ error: "Provide between 1 and 50 read books." }, 400);
  }
  const readBooks: RecapBook[] = [];
  for (const book of payload.readBooks) {
    if (!isRecord(book) || typeof book.title !== "string" || !book.title.trim()) {
      return json({ error: "Every read book must have a title." }, 400);
    }
    if (book.review !== undefined && book.review !== null && typeof book.review !== "string") {
      return json({ error: "Book reviews must be text." }, 400);
    }
    readBooks.push({
      title: book.title.trim().slice(0, 300),
      position: typeof book.position === "number" ? book.position : null,
      rating: typeof book.rating === "number" ? book.rating : null,
      review: typeof book.review === "string" ? book.review.trim().slice(0, 2_000) : null,
      finishedReadingAt: typeof book.finishedReadingAt === "string" ? book.finishedReadingAt : null
    });
  }
  const recapType = payload.recapType === "book" ? "book" : "series";
  const request: RecapRequest = { seriesName: payload.seriesName.trim().slice(0, 300), readBooks, sourceFingerprint: payload.sourceFingerprint.slice(0, 128), recapType };
  if (JSON.stringify(request).length > maximumCharacters) {
    return json({ error: "Recap input is too large." }, 413);
  }
  return request;
}

async function checkQuota(env: Env, dailyLimit: number, monthlyLimit: number): Promise<Usage | Response> {
  const now = new Date();
  const day = now.toISOString().slice(0, 10);
  const month = day.slice(0, 7);
  const existing = await env.RECAP_USAGE.get<Usage>(USAGE_KEY, "json");
  const usage: Usage = existing ?? { day, dayCount: 0, month, monthCount: 0 };
  if (usage.day !== day) { usage.day = day; usage.dayCount = 0; }
  if (usage.month !== month) { usage.month = month; usage.monthCount = 0; }
  if (usage.dayCount >= dailyLimit || usage.monthCount >= monthlyLimit) {
    return json({ error: "Recap quota reached. Try again later." }, 429);
  }
  return usage;
}

async function recordQuota(env: Env, usage: Usage): Promise<void> {
  usage.dayCount += 1;
  usage.monthCount += 1;
  await env.RECAP_USAGE.put(USAGE_KEY, JSON.stringify(usage));
}

function recapPrompt(request: RecapRequest): string {
  return JSON.stringify({
    subject: request.seriesName,
    recapType: request.recapType,
    boundary: request.recapType === "book"
      ? "The following single book is the complete spoiler boundary. Summarize that book only."
      : "The following list is the complete set of books this reader has finished. Do not use any other books.",
    detailLevel: "high",
    readBooks: request.readBooks
  });
}

function recapInstructions(recapType: RecapRequest["recapType"], useWebSearch = true, compact = false): string {
  const scope = recapType === "book"
    ? [
        "Write a thorough but readable summary of the completed book.",
        "Cover its beginning, major developments, characters, ending, and unresolved threads."
      ]
    : [
        "Write a thorough but readable series recap for the reader.",
        "Cover every supplied book in reading order, including later-book developments; do not stop after the early books."
      ];
  return [
    ...scope,
    useWebSearch
      ? "Research the supplied completed books on the public web before writing. The supplied completed-book titles are the spoiler boundary, not the only factual source."
      : "Web research is temporarily unavailable. Use reliable general knowledge for the supplied completed-book titles, which are the spoiler boundary; do not claim to have consulted sources.",
    "Never mention, summarize, imply events from, or name an unread or future book.",
    "Give concrete plot-specific detail: major causes and consequences, turning points, character motivations, relationships, antagonists, magic or world rules, and unresolved threads from the explicitly supplied read books.",
    "End with a clearly labeled 'Where things stand' section. State the confirmed final revelations and cliffhangers from the latest supplied book, including true identities or parentage, allegiances, supernatural status, active threats, relationship status, and a character's final location or condition whenever those facts matter to the plot.",
    useWebSearch
      ? "Do not replace a known ending revelation with vague language or a disclaimer. If a specific fact is not reliable after research, omit it rather than guessing."
      : "Do not replace a known ending revelation with vague language or a disclaimer. If a specific fact is not reliable, omit it rather than guessing.",
    "Use the reader's ratings and reviews only as personal context, not as facts about the books.",
    "Use clear sections or paragraphs when that helps. If you cannot reliably identify a supplied book, say so only for that book; do not let sparse reader notes weaken a recap for a recognizable completed book.",
    ...(compact ? [
      "The previous draft exceeded its space limit. Rewrite a complete, compact recap that fits this response: preserve every supplied book's key plot turns and ending, especially the latest book's final revelations, and use shorter sections rather than dropping the conclusion."
    ] : [])
  ].join(" ");
}

function recapOutputBudget(request: RecapRequest, maximum: number): number {
  // 10% above the original 800-token overview plus 900 tokens per book,
  // while retaining a firm cost ceiling for an on-demand personal recap.
  const requested = 880 + (990 * request.readBooks.length);
  return Math.min(maximum, requested);
}

function wasCutOff(response: OpenAIResponse): boolean {
  return response.status === "incomplete" && response.incomplete_details?.reason === "max_output_tokens";
}

function outputText(response: OpenAIResponse): string {
  return (response.output ?? [])
    .filter((item) => item.type === "message")
    .flatMap((item) => item.content ?? [])
    .filter((part) => part.type === "output_text" && typeof part.text === "string")
    .map((part) => part.text ?? "")
    .join("");
}

function recapWithSources(response: OpenAIResponse, recap: string): string {
  const sources = new Map<string, string>();
  for (const item of response.output ?? []) {
    if (item.type !== "message") continue;
    for (const part of item.content ?? []) {
      for (const annotation of part.annotations ?? []) {
        if (annotation.type === "url_citation" && annotation.url) {
          sources.set(annotation.url, annotation.title?.trim() || annotation.url);
        }
      }
    }
  }
  if (sources.size === 0) return recap;
  const sourceLines = Array.from(sources.entries()).slice(0, 5).map(([url, title]) => `- [${title}](${url})`);
  return `${recap}\n\nSources consulted\n${sourceLines.join("\n")}`;
}

function integer(value: string, fallback: number): number {
  const result = Number.parseInt(value, 10);
  return Number.isSafeInteger(result) && result > 0 ? result : fallback;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function json(body: Record<string, string>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
