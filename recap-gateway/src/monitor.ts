export interface MonitorEntity { kind: "book" | "author" | "series"; id: string; title: string; author?: string | null }
export interface MonitorEventSource { name: string; feedURL: string }
export interface Subscription { deviceIdentifier: string; deviceToken?: string; entities: MonitorEntity[]; eventSources: MonitorEventSource[]; updatedAt: string }
export interface MonitorEnv { MONITOR_SUBSCRIPTIONS: KVNamespace; MONITOR_STATE: KVNamespace; OPENAI_API_KEY?: string; APNS_KEY_ID?: string; APNS_TEAM_ID?: string; APNS_BUNDLE_ID?: string; APNS_PRIVATE_KEY?: string; APNS_ENVIRONMENT?: string }

export async function saveSubscription(request: Request, env: MonitorEnv): Promise<Response> {
  const body = await request.json().catch(() => null) as Partial<Subscription> | null;
  if (!body || !isIdentifier(body.deviceIdentifier) || (body.deviceToken !== undefined && !isToken(body.deviceToken)) || !Array.isArray(body.entities) || body.entities.length > 500 || !body.entities.every(validEntity) || (body.eventSources !== undefined && (!Array.isArray(body.eventSources) || body.eventSources.length > 30 || !body.eventSources.every(validEventSource)))) return json({ error: "Invalid monitoring subscription." }, 400);
  const subscription: Subscription = { deviceIdentifier: body.deviceIdentifier, deviceToken: body.deviceToken, entities: body.entities, eventSources: body.eventSources ?? [], updatedAt: new Date().toISOString() };
  await env.MONITOR_SUBSCRIPTIONS.put(`device:${subscription.deviceIdentifier}`, JSON.stringify(subscription));
  return json({ subscribed: "true" });
}

export async function runMonitor(env: MonitorEnv): Promise<void> {
  let cursor: string | undefined;
  try {
    let hasMore: boolean; const subscriptions: Subscription[] = [];
    do {
      const page = await env.MONITOR_SUBSCRIPTIONS.list({ prefix: "device:", cursor });
      hasMore = !page.list_complete;
      cursor = page.list_complete ? undefined : page.cursor;
      for (const key of page.keys) {
        const subscription = await env.MONITOR_SUBSCRIPTIONS.get<Subscription>(key.name, "json");
        if (subscription) subscriptions.push(subscription);
      }
    } while (hasMore);
    const entityChecks = new Map<string, Promise<string[]>>();
    const eventChecks = new Map<string, Promise<EventChange[]>>();
    for (const subscription of subscriptions) {
      const changes = (await Promise.all(subscription.entities.map(entity => {
        const key = `${entity.kind}:${entity.id}`;
        if (!entityChecks.has(key)) entityChecks.set(key, meaningfulChanges(entity, env));
        return entityChecks.get(key)!;
      }))).flat();
      const terms = subscription.entities.map(entity => entity.title.toLocaleLowerCase());
      const eventChanges = (await Promise.all(subscription.eventSources.map(source => {
        if (!eventChecks.has(source.feedURL)) eventChecks.set(source.feedURL, eventChangesFor(source, env));
        return eventChecks.get(source.feedURL)!;
      }))).flat().filter(event => terms.some(term => event.text.includes(term)));
      if ((changes.length || eventChanges.length) && subscription.deviceToken) await sendPush(subscription.deviceToken, [...changes, ...eventChanges.map(event => event.message)], env);
    }
  } catch (error) { console.error("Monitor run failed", error instanceof Error ? error.message : "unknown error"); throw error; }
}

interface Discovery { title: string; authorName: string; seriesName: string; releaseDate: string; sourceTitle: string; sourceURL: string }
interface DiscoveryResponse { discoveries: Discovery[] }
interface OpenAIResponse { output?: Array<{ type?: string; content?: Array<{ type?: string; text?: string; annotations?: Array<{ type?: string; url?: string }> }> }> }

/**
 * Runs only when the reader's scheduled Shortcut asks for an update. One
 * low-context, single-search request covers every followed author and series,
 * so this is a bounded personal-use alternative to always-on push monitoring.
 */
export async function discoverBooks(request: Request, env: MonitorEnv): Promise<Response> {
  const body = await request.json().catch(() => null) as { entities?: MonitorEntity[] } | null;
  if (!body || !Array.isArray(body.entities) || body.entities.length > 100 || !body.entities.every(validEntity)) return json({ error: "Invalid discovery request." }, 400);
  if (!env.OPENAI_API_KEY) return json({ error: "Web discovery is not configured." }, 503);
  const targets = body.entities.filter(entity => entity.kind === "author" || entity.kind === "series");
  if (targets.length === 0) return json({ discoveries: [] });

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { authorization: `Bearer ${env.OPENAI_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({
      model: "gpt-5.5",
      store: false,
      reasoning: { effort: "none" },
      max_output_tokens: 1_200,
      max_tool_calls: 1,
      tools: [{ type: "web_search", search_context_size: "low" }],
      tool_choice: "required",
      text: { format: { type: "json_schema", name: "book_discoveries", strict: true, schema: discoverySchema } },
      instructions: "Search the public web for newly announced or upcoming books connected to the supplied followed authors and series. Prefer publishers, author sites, and reputable book-industry sources. Return only books that are announced and not yet released. Never guess a title, date, author, series, or URL. Use an empty string when a release date or series is unknown. Every result must have a direct public source URL.",
      input: JSON.stringify(targets)
    })
  });
  if (!response.ok) return json({ error: "Web discovery is temporarily unavailable." }, 502);
  const result = await response.json() as OpenAIResponse;
  const text = outputText(result);
  let discoveries: DiscoveryResponse;
  try { discoveries = JSON.parse(text) as DiscoveryResponse; } catch { return json({ error: "Web discovery returned an invalid result." }, 502); }
  const citedURLs = citations(result);
  const verified = (discoveries.discoveries ?? []).filter(discovery => validDiscovery(discovery) && citedURLs.has(normalizedURL(discovery.sourceURL)));
  return json({ discoveries: verified.slice(0, 10) });
}

const discoverySchema = {
  type: "object",
  properties: {
    discoveries: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" }, authorName: { type: "string" }, seriesName: { type: "string" },
          releaseDate: { type: "string" }, sourceTitle: { type: "string" }, sourceURL: { type: "string" }
        },
        required: ["title", "authorName", "seriesName", "releaseDate", "sourceTitle", "sourceURL"],
        additionalProperties: false
      }
    }
  },
  required: ["discoveries"],
  additionalProperties: false
};

function outputText(response: OpenAIResponse): string {
  return (response.output ?? []).filter(item => item.type === "message").flatMap(item => item.content ?? []).filter(part => part.type === "output_text").map(part => part.text ?? "").join("");
}
function citations(response: OpenAIResponse): Set<string> {
  return new Set((response.output ?? []).flatMap(item => item.content ?? []).flatMap(part => part.annotations ?? []).filter(annotation => annotation.type === "url_citation" && annotation.url).map(annotation => normalizedURL(annotation.url!)));
}
function normalizedURL(value: string): string {
  try { const url = new URL(value); url.hash = ""; url.search = ""; return url.toString().replace(/\/$/, ""); } catch { return value; }
}
function validDiscovery(value: Discovery): boolean {
  return typeof value.title === "string" && value.title.trim().length > 0 && typeof value.authorName === "string" && value.authorName.trim().length > 0 && typeof value.seriesName === "string" && typeof value.releaseDate === "string" && typeof value.sourceTitle === "string" && typeof value.sourceURL === "string" && /^https:\/\//.test(value.sourceURL);
}

async function meaningfulChanges(entity: MonitorEntity, env: MonitorEnv): Promise<string[]> {
  if (entity.kind === "book") {
    const current = await releaseState(entity); if (!current) return [];
    const key = `release:${entity.id}`; const previous = await env.MONITOR_STATE.get<ReleaseState>(key, "json"); await env.MONITOR_STATE.put(key, JSON.stringify(current));
    if (!previous) return [];
    if (!previous.releaseDate && current.releaseDate) return [`${entity.title} now has a release date: ${current.releaseDate}.`];
    if (previous.releaseDate && current.releaseDate && previous.releaseDate !== current.releaseDate) return [`${entity.title}'s release date changed to ${current.releaseDate}.`];
    return [];
  }
  const current = await discoveredBooks(entity); const key = `books:${entity.kind}:${entity.id}`; const previous = await env.MONITOR_STATE.get<string[]>(key, "json"); await env.MONITOR_STATE.put(key, JSON.stringify(current));
  if (!previous) return [];
  return current.filter(title => !previous.includes(title)).slice(0, 3).map(title => `${title} is a newly discovered book related to ${entity.title}.`);
}

interface ReleaseState { releaseDate?: string; checkedAt: string }
async function releaseState(entity: MonitorEntity): Promise<ReleaseState | null> {
  const url = new URL("https://openlibrary.org/search.json");
  url.searchParams.set(entity.id.startsWith("/") ? "q" : "isbn", entity.id.startsWith("/") ? entity.title : entity.id);
  url.searchParams.set("limit", "1"); url.searchParams.set("fields", "publish_date,publish_year,first_publish_year");
  const response = await fetch(url); if (!response.ok) return null;
  const result = await response.json() as { docs?: Array<{ publish_date?: string[]; publish_year?: number[]; first_publish_year?: number }> };
  const document = result.docs?.[0]; if (!document) return null;
  const values = [...(document.publish_date ?? []), ...(document.publish_year ?? []).map(String), ...(document.first_publish_year ? [String(document.first_publish_year)] : [])];
  return { releaseDate: values.find(value => /^\d{4}(-\d{2}-\d{2})?$/.test(value)), checkedAt: new Date().toISOString() };
}

async function discoveredBooks(entity: MonitorEntity): Promise<string[]> {
  const url = new URL("https://openlibrary.org/search.json");
  if (entity.kind === "author") url.searchParams.set("author", entity.title);
  else url.searchParams.set("q", entity.title);
  url.searchParams.set("limit", "50"); url.searchParams.set("fields", "title,first_publish_year");
  const response = await fetch(url); if (!response.ok) return [];
  const result = await response.json() as { docs?: Array<{ title?: string; first_publish_year?: number }> };
  return [...new Set((result.docs ?? []).filter(book => !!book.title).map(book => book.title!).sort())];
}

interface EventChange { text: string; message: string }
async function eventChangesFor(source: MonitorEventSource, env: MonitorEnv): Promise<EventChange[]> {
  const response = await fetch(source.feedURL); if (!response.ok) return [];
  const text = await response.text(); const blocks = text.replace(/\r\n/g, "\n").split("BEGIN:VEVENT").slice(1).map(block => block.split("END:VEVENT")[0]);
  const events = blocks.map(block => ({ uid: property(block, "UID") ?? `${property(block, "SUMMARY")}:${property(block, "DTSTART")}`, title: property(block, "SUMMARY") ?? "Literary event", startsAt: property(block, "DTSTART") ?? "" })).filter(event => event.startsAt.slice(0, 8) >= new Date().toISOString().slice(0, 10).replace(/-/g, ""));
  const changes: EventChange[] = [];
  for (const event of events) {
    const key = `event:${source.feedURL}:${event.uid}`; const known = await env.MONITOR_STATE.get(key);
    await env.MONITOR_STATE.put(key, "1", { expirationTtl: 60 * 60 * 24 * 400 });
    if (known) continue;
    const feedInitialized = await env.MONITOR_STATE.get(`event-source:${source.feedURL}`);
    if (feedInitialized) changes.push({ text: event.title.toLocaleLowerCase(), message: `New event: ${event.title}.` });
  }
  await env.MONITOR_STATE.put(`event-source:${source.feedURL}`, "1", { expirationTtl: 60 * 60 * 24 * 400 });
  return changes;
}
function property(block: string, name: string): string | undefined { const line = block.split("\n").find(line => line.startsWith(`${name}:`) || line.startsWith(`${name};`)); return line?.slice(line.indexOf(":") + 1).trim(); }

async function sendPush(deviceToken: string, changes: string[], env: MonitorEnv): Promise<void> {
  if (!env.APNS_KEY_ID || !env.APNS_TEAM_ID || !env.APNS_BUNDLE_ID || !env.APNS_PRIVATE_KEY) { console.log("Monitor change found; APNs is not configured.", changes); return; }
  const jwt = await apnsJWT({ APNS_KEY_ID: env.APNS_KEY_ID, APNS_TEAM_ID: env.APNS_TEAM_ID, APNS_PRIVATE_KEY: env.APNS_PRIVATE_KEY });
  const host = env.APNS_ENVIRONMENT === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const response = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: { authorization: `bearer ${jwt}`, "apns-topic": env.APNS_BUNDLE_ID, "apns-push-type": "alert", "content-type": "application/json" },
    body: JSON.stringify({ aps: { alert: { title: "Book Buddy update", body: changes[0] }, sound: "default" }, changes: changes.slice(0, 3) })
  });
  if (!response.ok) throw new Error(`APNs delivery failed (${response.status})`);
}

async function apnsJWT(env: Required<Pick<MonitorEnv, "APNS_KEY_ID" | "APNS_TEAM_ID" | "APNS_PRIVATE_KEY">>): Promise<string> {
  const encoder = new TextEncoder(); const header = base64URL(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID })); const payload = base64URL(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) }));
  const pem = env.APNS_PRIVATE_KEY.replace(/\\n/g, "\n").replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", base64Bytes(pem), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(`${header}.${payload}`));
  return `${header}.${payload}.${base64URL(signature)}`;
}
function base64URL(value: string | ArrayBuffer): string { const bytes = typeof value === "string" ? new TextEncoder().encode(value) : new Uint8Array(value); let binary = ""; for (const byte of bytes) binary += String.fromCharCode(byte); return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_"); }
function base64Bytes(value: string): ArrayBuffer { const binary = atob(value); const bytes = new Uint8Array(binary.length); for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i); return bytes.buffer; }

function validEntity(value: unknown): value is MonitorEntity { return !!value && typeof value === "object" && ["book", "author", "series"].includes((value as MonitorEntity).kind) && isIdentifier((value as MonitorEntity).id) && typeof (value as MonitorEntity).title === "string" && (value as MonitorEntity).title.length > 0 && (value as MonitorEntity).title.length <= 300; }
function validEventSource(value: unknown): value is MonitorEventSource { return !!value && typeof value === "object" && typeof (value as MonitorEventSource).name === "string" && (value as MonitorEventSource).name.length <= 300 && typeof (value as MonitorEventSource).feedURL === "string" && /^https:\/\//.test((value as MonitorEventSource).feedURL) && (value as MonitorEventSource).feedURL.length <= 2_000; }
function isIdentifier(value: unknown): value is string { return typeof value === "string" && value.length > 0 && value.length <= 300; }
function isToken(value: unknown): value is string { return typeof value === "string" && /^[0-9a-f]{32,}$/i.test(value); }
function json(body: Record<string, unknown>, status = 200): Response { return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8" } }); }
