# open-brain

A single-page dashboard that monitors *multiple* agent runtimes side-by-side.
Each backend (Larry, a hypothetical Codex daemon, a Stripe poller, etc.) is a
**node**. The dashboard polls each node's `/api/status` endpoint on a
configurable interval and renders a card per node.

## Quickstart

```cmd
:: serve the static page on port 18900
cd C:\Users\simon\openbrain
python -m http.server 18900 --bind 127.0.0.1
```

Then open http://127.0.0.1:18900/

The first node, **Larry**, should already be configured (see `nodes.json`).

## Node spec

A runtime is a valid open-brain node if it answers `GET <base_url>/api/status`
with a JSON object that includes at least:

| field            | type      | required | meaning |
|------------------|-----------|----------|---------|
| `version`        | string    | optional | semver of the runtime |
| `providers`      | string[]  | optional | upstream model providers wired up |
| `default_provider` | string  | optional | the routing default |
| `cron_job_count` | integer   | optional | how many recurring jobs are scheduled |
| `telegram`       | boolean   | optional | telegram channel up |
| `tools_enabled`  | boolean   | optional | tool-calling on |
| `skills`         | string[]  | optional | list of loaded skill ids |
| `larry_home`     | string    | optional | filesystem root of this runtime |
| `workspace_root` | string    | optional | filesystem root of the user's workspace |

Larry is the reference implementation. Any of the optional fields render in
the dashboard if present; missing fields are simply skipped. So a minimal
"is-it-up" node only needs to return `{ "version": "x" }` (or even `{}`).

Optional auxiliary endpoints (the dashboard isn't required to call them, but
future open-brain views can):

- `GET /api/cron` — list of scheduled jobs and their last-run state
- `GET /api/cron/runs` — last-N cron runs (jsonl tail)
- `GET /api/sessions` — list session transcripts (name, size, mtime)
- `GET /api/sessions/:name` — return one transcript as JSON array
- `GET /api/tools` — last-N tool audit entries
- `POST /api/cron/run` — trigger a job: `{ "job_id": "..." }`
- `POST /api/ask` — ad-hoc prompt: `{ "prompt", "provider"?, "model"? }`

CORS: every node should allow any-origin GET so a static dashboard can poll
it from a different port.

## Adding a new node

Edit `nodes.json`. Each entry:

```json
{
  "id": "stripe-monitor",
  "name": "Stripe Monitor",
  "kind": "stripe",
  "base_url": "http://127.0.0.1:18801",
  "token": null,
  "refresh_s": 30,
  "color": "#6ec07e"
}
```

- `id` — unique, slug-style.
- `kind` — free-text label; future open-brain views can specialise per-kind.
- `base_url` — without trailing slash. The dashboard will append `/api/status`.
- `token` — optional bearer token sent as `Authorization: Bearer <token>`.
- `refresh_s` — page-level poll cadence is `min(node.refresh_s)` across all nodes.
- `color` — left-border accent.

Reload the page after editing.

## Why this exists

Each business module (RivalDrop, Ecolibrium, Stripe poller, Resend bridge,
the workspace librarian, the AI Scout, etc.) tends to grow into its own
long-running process. Without a roof over them, you only know one is broken
when the cron silently stops firing or a Telegram message goes missing.
open-brain gives you one page that tells you "is each of these running, and
what was each one doing 30 seconds ago", with no agent involvement required.

It is intentionally **dumb**: vanilla HTML + JS, no build step, no framework,
no auth (relies on loopback only). Add complexity only when a specific node's
needs justify it.
