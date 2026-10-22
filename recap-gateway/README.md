# Book Buddy Recap and Monitoring Worker

This Cloudflare Worker is the secure server-side boundary between the Book Buddy iPhone app and the OpenAI Responses API. It never exposes `OPENAI_API_KEY` to the app.

## Guardrails

- Fixed model: `gpt-6-luna`
- Output budget: scales by the number of read books, up to 6,600 tokens
- Default quota: 20 recaps/day and 100 recaps/month
- Local bookstore lookups: 6/day and 24/month by default. They are always
  reader-initiated and send only a city-level search area plus book metadata.
- Maximum request payload: 20,000 characters
- Gateway bearer-token check before any OpenAI request
- OpenAI response storage disabled with `store: false`
- The Worker sends only books marked Read by the iPhone app
- Safe error codes identify upstream authentication, billing, or model-access failures without returning provider response bodies

The gateway token is an access gate, not a substitute for per-user authentication. For this personal-use MVP, keep the quotas low and rotate the token if it is exposed. A multi-user version should authenticate each user (for example, with Sign in with Apple) before permitting recap requests.

## Local bookstore lookup

The iPhone can use the existing recap-gateway connection to call
`/v1/local-bookstores`. The Worker searches public sites of independent
bookstores in the reader's supplied city or area. A result is marked **Listed
as available** only when that store's own page explicitly supports it;
otherwise it is labeled **Check with store**. The feature never runs in the
background and does not receive a precise device location.

## Background monitoring

The Worker checks subscribed books, authors, series, and enabled event feeds every six hours. It stores only an anonymous device ID, APNs device token, and the things the reader chose to follow.

To deliver detected changes as push notifications, set `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, and `APNS_PRIVATE_KEY` as Worker secrets. Set `APNS_ENVIRONMENT=production` for release builds; development is the default. Until those credentials are set, the scheduled monitor can check state but cannot notify a phone.

## Deploy

1. Install dependencies: `npm install`.
2. Authenticate Wrangler: `npx wrangler login`.
3. Deploy: `npm run deploy`. Wrangler automatically provisions the `RECAP_USAGE` KV namespace from `wrangler.jsonc`.
4. Set secrets interactively; do not add them to any file:

   ```sh
   npx wrangler secret put OPENAI_API_KEY
   npx wrangler secret put CLIENT_TOKEN
   ```

5. Copy the deployed `https://…workers.dev/v1/recaps` URL. The current iOS app deliberately remains unconfigured until an endpoint and access token are supplied through a future secure-connection screen; it never contains the OpenAI API key.

For local development only, copy `.dev.vars.example` to `.dev.vars` and replace its placeholders. `.dev.vars` is gitignored.
